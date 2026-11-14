import logging
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, desc
from sqlalchemy.exc import IntegrityError

from backend.models.complaint import Complaint
from backend.models.escalation import EscalationRule, EscalationEvent
from backend.models.status_history import StatusHistory
from backend.models.user import User
from backend.models.enums import UserRole, ComplaintStatus
from backend.services.deadline_service import is_overdue, calculate_overdue_hours
from backend.services.notification_service import dispatch_notification_safe

logger = logging.getLogger("civicai.escalation")

# Maximum escalation level before the complaint reaches the highest authority
# Level 0  → Officer          (initial assignment, no escalation yet)
# Level 1  → Supervisor       (1st SLA breach — first real escalation)
# Level 2  → Admin/Municipal Commissioner (2nd SLA breach — final escalation)
DEFAULT_MAX_ESCALATION_LEVEL = 2

# Default municipal authority hierarchy when no custom rule is present in DB
DEFAULT_ROLE_HIERARCHY = {
    1: UserRole.SUPERVISOR.value,   # Level 1: Dept Supervisor (1st SLA breach)
    2: UserRole.ADMIN.value,        # Level 2: Municipal Commissioner / Admin (2nd SLA breach)
}

DEFAULT_TRIGGER_HOURS_PER_LEVEL = {
    1: 24,   # Supervisor gets 24 h to act after first breach
    2: 48,   # Admin gets 48 h to act after second breach
}


def get_escalation_rule_for_level(
    db: Session,
    department_id: int,
    category_id: int,
    target_level: int,
) -> Optional[EscalationRule]:
    """
    Find matching active escalation rule with fallback hierarchy:
    1. Category-specific rule
    2. Department-wide rule
    3. Global municipal rule
    """
    # 1. Exact Category Rule
    rule = (
        db.query(EscalationRule)
        .filter(
            EscalationRule.department_id == department_id,
            EscalationRule.category_id == category_id,
            EscalationRule.escalation_level == target_level,
            EscalationRule.is_active.is_(True),
        )
        .first()
    )
    if rule:
        return rule

    # 2. Department-wide Rule
    rule = (
        db.query(EscalationRule)
        .filter(
            EscalationRule.department_id == department_id,
            EscalationRule.category_id.is_(None),
            EscalationRule.escalation_level == target_level,
            EscalationRule.is_active.is_(True),
        )
        .first()
    )
    if rule:
        return rule

    # 3. Global Rule
    rule = (
        db.query(EscalationRule)
        .filter(
            EscalationRule.department_id.is_(None),
            EscalationRule.category_id.is_(None),
            EscalationRule.escalation_level == target_level,
            EscalationRule.is_active.is_(True),
        )
        .first()
    )
    return rule


def find_target_authority_user(
    db: Session,
    target_role: str,
    department_id: Optional[int] = None,
) -> Optional[User]:
    """
    Locate an active municipal officer/supervisor/admin matching target role.
    Prioritizes matching the complaint's department.
    """
    # Try within department first
    if department_id:
        user = (
            db.query(User)
            .filter(
                User.role == target_role,
                User.department_id == department_id,
                User.is_active.is_(True),
            )
            .first()
        )
        if user:
            return user

    # Fallback: any active user with that role
    return (
        db.query(User)
        .filter(
            User.role == target_role,
            User.is_active.is_(True),
        )
        .first()
    )


def escalate_complaint(
    db: Session,
    complaint_id: int,
    reason: Optional[str] = None,
    trigger_type: str = "automatic",
    actor: Optional[User] = None,
    max_level: int = DEFAULT_MAX_ESCALATION_LEVEL,
) -> Dict[str, Any]:
    """
    Execute atomic escalation for a single complaint.
    Ensures idempotency, transactional integrity, timeline tracking, and in-app alerts.
    """
    now = datetime.now(timezone.utc)

    # Fetch complaint with row-level lock on supported engines (PostgreSQL)
    query = db.query(Complaint).filter(Complaint.id == complaint_id)
    if db.bind and db.bind.dialect.name != "sqlite":
        query = query.with_for_update()

    complaint = query.first()
    if not complaint:
        return {"success": False, "reason": "complaint_not_found"}

    # 1. Eligibility Check: Terminal statuses cannot be escalated
    terminal_statuses = [ComplaintStatus.RESOLVED.value, ComplaintStatus.REJECTED.value]
    if complaint.status in terminal_statuses:
        logger.info(f"Skipping Complaint #{complaint.complaint_number}: status is {complaint.status}")
        return {"success": False, "reason": "terminal_status", "status": complaint.status}

    # 2. Maximum level check
    current_level = complaint.escalation_level
    next_level = current_level + 1
    if current_level >= max_level:
        logger.info(
            f"Skipping Complaint #{complaint.complaint_number}: already at max escalation level ({current_level})"
        )
        return {"success": False, "reason": "already_max_level", "level": current_level}

    # 3. Duplicate Escalation Prevention (Idempotency Check)
    existing_event = (
        db.query(EscalationEvent)
        .filter(
            EscalationEvent.complaint_id == complaint.id,
            EscalationEvent.to_level == next_level,
        )
        .first()
    )
    if existing_event:
        logger.warning(
            f"Duplicate escalation prevented: Complaint #{complaint.complaint_number} already escalated to level {next_level}"
        )
        return {
            "success": False,
            "reason": "duplicate_escalation_prevented",
            "event_id": existing_event.id,
            "level": next_level,
        }

    # 4. Resolve Target Authority & Rules
    rule = get_escalation_rule_for_level(
        db=db,
        department_id=complaint.department_id,
        category_id=complaint.category_id,
        target_level=next_level,
    )

    if rule:
        target_role = rule.target_role
        extension_hours = rule.trigger_hours
    else:
        target_role = DEFAULT_ROLE_HIERARCHY.get(next_level, UserRole.ADMIN.value)
        extension_hours = DEFAULT_TRIGGER_HOURS_PER_LEVEL.get(next_level, 24)

    target_user = find_target_authority_user(
        db=db,
        target_role=target_role,
        department_id=complaint.department_id,
    )

    if not target_user:
        logger.warning(
            f"Escalation aborted for Complaint #{complaint.id} ({complaint.complaint_number}): "
            f"No target authority user found with role '{target_role}' for escalation level {next_level}."
        )
        return {
            "success": False,
            "reason": "target_authority_not_found",
            "complaint_id": complaint.id,
            "complaint_number": complaint.complaint_number,
            "escalation_level": next_level,
            "target_role": target_role,
            "detail": f"Target authority user not found for role '{target_role}' at escalation level {next_level}",
        }

    # Calculate SLA delay
    overdue_hours = calculate_overdue_hours(complaint.due_at, now)
    escalation_reason = reason or (
        f"Overdue by {overdue_hours:.1f} hours beyond SLA due date"
        if overdue_hours > 0
        else f"Manual escalation to Level {next_level} by {actor.role if actor else 'system'}"
    )

    prev_assigned_id = complaint.assigned_officer_id
    prev_status = complaint.status
    complaint_num = complaint.complaint_number

    try:
        # 5. Insert Immutable Escalation Event
        escalation_event = EscalationEvent(
            complaint_id=complaint.id,
            from_level=current_level,
            to_level=next_level,
            reason=escalation_reason,
            escalated_from_id=prev_assigned_id,
            escalated_to_id=target_user.id,
            trigger_type=trigger_type,
            deadline_exceeded_hours=overdue_hours,
            created_at=now,
        )
        db.add(escalation_event)

        # 6. Update Complaint State
        complaint.escalation_level = next_level
        complaint.status = ComplaintStatus.ESCALATED.value
        complaint.assigned_officer_id = target_user.id

        # Extend due_at for the newly responsible authority to act
        complaint.due_at = now + timedelta(hours=extension_hours)
        complaint.updated_at = now

        # 7. Add Status History Timeline Log
        history = StatusHistory(
            complaint_id=complaint.id,
            previous_status=prev_status,
            new_status=ComplaintStatus.ESCALATED.value,
            changed_by_id=actor.id if actor else None,
            comments=f"Escalated from Level {current_level} to Level {next_level} ({target_role}). {escalation_reason}",
            created_at=now,
        )
        db.add(history)

        # 8. Dispatch In-App Notifications
        # A) Alert to the newly assigned authority
        dispatch_notification_safe(
            db=db,
            user_id=target_user.id,
            title=f"Grievance Escalation Alert: #{complaint_num}",
            message=(
                f"Complaint #{complaint_num} ('{complaint.title}') has been escalated "
                f"to Level {next_level} ({target_role}). Reason: {escalation_reason}. "
                f"Next deadline: {complaint.due_at.strftime('%Y-%m-%d %H:%M UTC')}."
            ),
            complaint_id=complaint.id,
            notification_type="escalation",
        )

        # B) Courtesy update to the citizen
        if complaint.citizen_id:
            dispatch_notification_safe(
                db=db,
                user_id=complaint.citizen_id,
                title=f"Update on Grievance #{complaint_num}",
                message=(
                    f"Your complaint #{complaint_num} has been escalated to "
                    f"{target_role.capitalize()} for expedited resolution."
                ),
                complaint_id=complaint.id,
                notification_type="escalation_update",
            )

        # Commit transaction atomically
        db.commit()
        db.refresh(escalation_event)
        db.refresh(complaint)

        logger.info(
            f"Successfully escalated Complaint #{complaint_num} to Level {next_level} (Assigned: {target_user.email if target_user else 'Unassigned'})"
        )

        return {
            "success": True,
            "complaint_id": complaint.id,
            "complaint_number": complaint_num,
            "event_id": escalation_event.id,
            "from_level": current_level,
            "to_level": next_level,
            "target_role": target_role,
            "assigned_to_id": target_user.id if target_user else None,
            "new_due_at": complaint.due_at.isoformat(),
        }

    except IntegrityError as exc:
        db.rollback()
        logger.warning(
            f"Concurrent duplicate escalation race prevented by DB constraint for Complaint #{complaint_num}: {exc}"
        )
        return {
            "success": False,
            "reason": "duplicate_escalation_prevented",
            "detail": "Database unique constraint caught concurrent escalation attempt",
        }
    except Exception as exc:
        db.rollback()
        logger.error(f"Failed to escalate Complaint #{complaint_num}: {exc}", exc_info=True)
        return {"success": False, "reason": "database_error", "detail": str(exc)}


def check_and_escalate_overdue_complaints(
    db: Session,
    max_level: int = DEFAULT_MAX_ESCALATION_LEVEL,
) -> Dict[str, Any]:
    """
    Overdue Complaint Checker:
    Queries all unresolved grievances with expired SLA deadlines and executes escalations safely.
    """
    start_time = time.time()
    now = datetime.now(timezone.utc)

    logger.info("=== Automatic Overdue Complaint Checker Started ===")

    # Exclude resolved or rejected
    excluded_statuses = [ComplaintStatus.RESOLVED.value, ComplaintStatus.REJECTED.value]

    query = (
        db.query(Complaint.id)
        .filter(
            Complaint.status.notin_(excluded_statuses),
            Complaint.due_at <= now,
            Complaint.escalation_level < max_level,
        )
        .order_by(Complaint.due_at.asc())
    )

    overdue_ids = [row[0] for row in query.all()]
    total_found = len(overdue_ids)
    logger.info(f"Identified {total_found} candidate overdue complaint(s).")

    escalated_count = 0
    skipped_count = 0
    failed_count = 0
    details = []

    for cid in overdue_ids:
        result = escalate_complaint(
            db=db,
            complaint_id=cid,
            trigger_type="automatic",
            max_level=max_level,
        )
        if result.get("success"):
            escalated_count += 1
            details.append({"complaint_id": cid, "status": "escalated", "level": result.get("to_level")})
        elif result.get("reason") in ["duplicate_escalation_prevented", "already_max_level", "terminal_status"]:
            skipped_count += 1
            details.append({"complaint_id": cid, "status": "skipped", "reason": result.get("reason")})
        else:
            failed_count += 1
            details.append({"complaint_id": cid, "status": "failed", "detail": result.get("detail")})

    elapsed = round(time.time() - start_time, 3)
    summary = {
        "timestamp": now.isoformat(),
        "checked": total_found,
        "escalated": escalated_count,
        "skipped": skipped_count,
        "failed": failed_count,
        "duration_seconds": elapsed,
        "details": details,
    }

    logger.info(
        f"=== Overdue Checker Finished in {elapsed}s: "
        f"{escalated_count} escalated, {skipped_count} skipped, {failed_count} failed ==="
    )
    return summary


def get_complaint_escalation_history(
    db: Session,
    complaint_id: int,
) -> List[EscalationEvent]:
    """Retrieve full chronological escalation history for a complaint."""
    return (
        db.query(EscalationEvent)
        .filter(EscalationEvent.complaint_id == complaint_id)
        .order_by(EscalationEvent.created_at.asc())
        .all()
    )


def acknowledge_escalation_event(
    db: Session,
    event_id: int,
    user: User,
) -> Optional[EscalationEvent]:
    """Mark an escalation event as acknowledged by a supervisor or higher authority."""
    event = db.query(EscalationEvent).filter(EscalationEvent.id == event_id).first()
    if not event:
        return None

    now = datetime.now(timezone.utc)
    event.acknowledged_at = now
    event.acknowledged_by_id = user.id

    # Also log acknowledgement in StatusHistory
    history = StatusHistory(
        complaint_id=event.complaint_id,
        previous_status=ComplaintStatus.ESCALATED.value,
        new_status=ComplaintStatus.ESCALATED.value,
        changed_by_id=user.id,
        comments=f"Escalation event #{event.id} (Level {event.to_level}) acknowledged by {user.role} {user.full_name}",
        created_at=now,
    )
    db.add(history)
    db.commit()
    db.refresh(event)
    return event
