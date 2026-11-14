"""SLA escalation engine.

Complaints that miss their SLA deadline are progressively escalated through the
configured authority chain. Each level is applied at most once per complaint,
which keeps the engine idempotent and safe to run on a timer.
"""

from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session

from backend.core.config import settings
from backend.models.complaint import Complaint
from backend.models.enums import ComplaintStatus, UserRole
from backend.models.escalation import EscalationEvent, EscalationRule
from backend.models.status_history import StatusHistory
from backend.models.user import User
from backend.services.audit import record_audit
from backend.services.notifications import notify_users

OPEN_STATUSES = [
    ComplaintStatus.SUBMITTED.value,
    ComplaintStatus.ASSIGNED.value,
    ComplaintStatus.IN_PROGRESS.value,
    ComplaintStatus.ESCALATED.value,
]


def as_utc(value: datetime) -> datetime:
    """SQLite returns naive datetimes; normalise everything to aware UTC."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _select_rule(
    db: Session, complaint: Complaint, level: int
) -> Optional[EscalationRule]:
    """Pick the most specific rule for this department/category and level."""
    rules = (
        db.query(EscalationRule)
        .filter(EscalationRule.escalation_level == level)
        .all()
    )
    matches = [
        rule
        for rule in rules
        if (rule.department_id is None or rule.department_id == complaint.department_id)
        and (rule.category_id is None or rule.category_id == complaint.category_id)
    ]
    if not matches:
        return None

    # Department+category specific > department specific > global.
    matches.sort(
        key=lambda rule: (
            rule.department_id is not None,
            rule.category_id is not None,
        ),
        reverse=True,
    )
    return matches[0]


def _recipients(db: Session, rule: EscalationRule, complaint: Complaint) -> list[User]:
    query = db.query(User).filter(
        User.role == rule.target_role, User.is_active.is_(True)
    )
    if rule.target_role == UserRole.SUPERVISOR.value and complaint.department_id:
        query = query.filter(
            or_(
                User.department_id == complaint.department_id,
                User.department_id.is_(None),
            )
        )
    users = query.order_by(User.id.asc()).all()

    # If no supervisor exists for a department, fall back to municipal admins.
    if not users and rule.target_role != UserRole.ADMIN.value:
        users = (
            db.query(User)
            .filter(User.role == UserRole.ADMIN.value, User.is_active.is_(True))
            .order_by(User.id.asc())
            .all()
        )
    return users


def process_escalations(db: Session, now: Optional[datetime] = None) -> list[EscalationEvent]:
    """Apply every due escalation level. Returns newly created events."""
    now = now or datetime.now(timezone.utc)
    created: list[EscalationEvent] = []

    complaints = (
        db.query(Complaint)
        .filter(
            Complaint.status.in_(OPEN_STATUSES),
            Complaint.due_at.isnot(None),
            Complaint.escalation_level < settings.MAX_ESCALATION_LEVEL,
        )
        .order_by(Complaint.due_at.asc())
        .limit(500)
        .all()
    )

    for complaint in complaints:
        due_at = as_utc(complaint.due_at)
        next_level = (complaint.escalation_level or 0) + 1

        while next_level <= settings.MAX_ESCALATION_LEVEL:
            rule = _select_rule(db, complaint, next_level)
            if rule is None:
                break

            trigger_at = due_at + timedelta(hours=rule.trigger_hours)
            if now < trigger_at:
                break

            # Idempotency guard: never create the same level twice.
            exists = (
                db.query(EscalationEvent)
                .filter(
                    EscalationEvent.complaint_id == complaint.id,
                    EscalationEvent.to_level == next_level,
                )
                .first()
            )
            if exists:
                next_level += 1
                continue

            recipients = _recipients(db, rule, complaint)
            overdue_hours = max(0.0, (now - due_at).total_seconds() / 3600.0)
            if overdue_hours < 0.5:
                timing = "SLA deadline reached."
            else:
                hours_text = (
                    f"{overdue_hours:.0f}h"
                    if overdue_hours >= 10
                    else f"{overdue_hours:.1f}h"
                )
                timing = f"SLA deadline exceeded by {hours_text}."
            reason = (
                f"{timing} "
                f"Auto-escalated to level {next_level} ({rule.target_role})."
            )

            event = EscalationEvent(
                complaint_id=complaint.id,
                from_level=complaint.escalation_level or 0,
                to_level=next_level,
                reason=reason,
                escalated_to_id=recipients[0].id if recipients else None,
                created_at=now,
            )
            db.add(event)
            created.append(event)

            previous_status = complaint.status
            complaint.escalation_level = next_level
            complaint.status = ComplaintStatus.ESCALATED.value
            complaint.updated_at = now

            db.add(
                StatusHistory(
                    complaint_id=complaint.id,
                    previous_status=previous_status,
                    new_status=ComplaintStatus.ESCALATED.value,
                    changed_by_id=None,
                    comments=reason,
                    created_at=now,
                )
            )

            notify_users(
                db,
                [user.id for user in recipients]
                + [complaint.citizen_id, complaint.assigned_officer_id],
                title=f"Complaint escalated to level {next_level}",
                message=(
                    f"{complaint.complaint_number} — {complaint.title} has breached its SLA "
                    f"and was escalated to {rule.target_role}."
                ),
                notification_type="escalation",
                complaint_id=complaint.id,
            )

            record_audit(
                db,
                user=None,
                action="complaint.escalated",
                resource_type="complaint",
                resource_id=complaint.id,
                details=reason,
            )

            next_level += 1

    if created:
        db.commit()
    return created
