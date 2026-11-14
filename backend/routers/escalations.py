from collections import Counter, defaultdict
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, joinedload

from backend.core.database import get_db
from backend.core.deps import require_roles
from backend.models.complaint import Complaint
from backend.models.enums import UserRole
from backend.models.escalation import EscalationEvent, EscalationRule
from backend.models.user import User
from backend.schemas.escalation import (
    EscalationEventDetail,
    EscalationEventResponse,
    EscalationRuleCreate,
    EscalationRuleResponse,
    EscalationRunResponse,
    EscalationSummary,
)
from backend.services.audit import record_audit
from backend.services.escalation_engine import process_escalations
from backend.services.scoping import apply_complaint_scope

router = APIRouter(prefix="/escalations", tags=["Escalations"])


def _event_detail(event: EscalationEvent) -> EscalationEventDetail:
    complaint = event.complaint
    return EscalationEventDetail(
        id=event.id,
        complaint_id=event.complaint_id,
        from_level=event.from_level,
        to_level=event.to_level,
        reason=event.reason,
        escalated_to_id=event.escalated_to_id,
        created_at=event.created_at,
        complaint_number=complaint.complaint_number if complaint else None,
        complaint_title=complaint.title if complaint else None,
        department=(
            complaint.department.name
            if complaint and complaint.department
            else None
        ),
        escalated_to_name=event.escalated_to.full_name if event.escalated_to else None,
    )


@router.get("/events", response_model=List[EscalationEventDetail])
def list_escalation_events(
    limit: int = Query(50, ge=1, le=200),
    skip: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles(
            [
                UserRole.CITIZEN,
                UserRole.OFFICER,
                UserRole.SUPERVISOR,
                UserRole.ADMIN,
            ]
        )
    ),
):
    """Escalation history, scoped to what the caller may see."""
    query = (
        db.query(EscalationEvent)
        .join(Complaint, EscalationEvent.complaint_id == Complaint.id)
        .options(
            joinedload(EscalationEvent.complaint).joinedload(Complaint.department),
            joinedload(EscalationEvent.escalated_to),
        )
    )
    query = apply_complaint_scope(query, current_user)
    events = (
        query.order_by(EscalationEvent.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_event_detail(event) for event in events]


@router.get("/summary", response_model=EscalationSummary)
def escalation_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles([UserRole.SUPERVISOR, UserRole.ADMIN])
    ),
):
    query = (
        db.query(EscalationEvent)
        .join(Complaint, EscalationEvent.complaint_id == Complaint.id)
        .options(joinedload(EscalationEvent.complaint).joinedload(Complaint.department))
    )
    query = apply_complaint_scope(query, current_user)
    events = query.all()

    by_level = Counter(str(event.to_level) for event in events)
    dept_counts: dict[str, int] = defaultdict(int)
    for event in events:
        dept = (
            event.complaint.department.name
            if event.complaint and event.complaint.department
            else "Unknown"
        )
        dept_counts[dept] += 1

    open_escalated = (
        db.query(Complaint)
        .filter(
            Complaint.status == "escalated",
            Complaint.escalation_level > 0,
        )
        .count()
    )

    return EscalationSummary(
        total_events=len(events),
        open_escalated=open_escalated,
        by_level=dict(sorted(by_level.items())),
        by_department=[
            {"department": name, "count": count}
            for name, count in sorted(
                dept_counts.items(), key=lambda item: item[1], reverse=True
            )
        ],
    )


@router.post("/run", response_model=EscalationRunResponse)
def run_escalation_check(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles([UserRole.SUPERVISOR, UserRole.ADMIN])
    ),
):
    """Trigger the SLA escalation sweep immediately."""
    events = process_escalations(db)
    record_audit(
        db,
        user=current_user,
        action="escalation.run",
        resource_type="system",
        details=f"{len(events)} complaint(s) escalated",
    )
    db.commit()
    return EscalationRunResponse(
        escalated=len(events),
        events=[EscalationEventResponse.model_validate(event) for event in events],
    )


@router.get("/rules", response_model=List[EscalationRuleResponse])
def list_escalation_rules(
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles([UserRole.SUPERVISOR, UserRole.ADMIN])),
):
    return (
        db.query(EscalationRule)
        .order_by(EscalationRule.escalation_level.asc(), EscalationRule.id.asc())
        .all()
    )


@router.post(
    "/rules", response_model=EscalationRuleResponse, status_code=status.HTTP_201_CREATED
)
def create_escalation_rule(
    payload: EscalationRuleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN])),
):
    rule = EscalationRule(
        department_id=payload.department_id,
        category_id=payload.category_id,
        escalation_level=payload.escalation_level,
        trigger_hours=payload.trigger_hours,
        target_role=payload.target_role,
    )
    db.add(rule)
    record_audit(
        db,
        user=current_user,
        action="escalation_rule.created",
        resource_type="escalation_rule",
        details=f"level={payload.escalation_level} after {payload.trigger_hours}h",
    )
    db.commit()
    db.refresh(rule)
    return rule


@router.delete("/rules/{rule_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_escalation_rule(
    rule_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN])),
):
    rule = db.query(EscalationRule).filter(EscalationRule.id == rule_id).first()
    if not rule:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Escalation rule not found"
        )
    db.delete(rule)
    record_audit(
        db,
        user=current_user,
        action="escalation_rule.deleted",
        resource_type="escalation_rule",
        resource_id=rule_id,
    )
    db.commit()
    return None
