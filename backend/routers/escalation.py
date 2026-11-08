from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, desc

from backend.core.database import get_db
from backend.core.deps import get_current_user, require_roles
from backend.models.complaint import Complaint
from backend.models.escalation import EscalationRule, EscalationEvent
from backend.models.user import User
from backend.models.department import Department
from backend.models.category import ComplaintCategory
from backend.models.enums import UserRole, ComplaintStatus
from backend.schemas.common import MessageResponse
from backend.schemas.complaint import ComplaintResponse
from backend.schemas.escalation import (
    EscalationRuleCreate,
    EscalationRuleUpdate,
    EscalationRuleResponse,
    EscalationEventResponse,
    ManualEscalateRequest,
    DeadlineExtensionRequest,
    CheckerExecutionSummary,
    WorkerStatusResponse,
)
from backend.services.escalation_service import (
    escalate_complaint,
    check_and_escalate_overdue_complaints,
    get_complaint_escalation_history,
    acknowledge_escalation_event,
)
from backend.services.deadline_service import extend_deadline
from backend.workers.escalation_worker import get_worker_status

router = APIRouter(tags=["Escalation Engine"])


# ==========================================
# 1. ESCALATION RULES MANAGEMENT (ADMIN)
# ==========================================

@router.get(
    "/escalation/rules",
    response_model=List[EscalationRuleResponse],
    summary="List escalation rules (Admin)",
)
def list_escalation_rules(
    department_id: Optional[int] = Query(None, description="Filter by department"),
    category_id: Optional[int] = Query(None, description="Filter by category"),
    is_active: Optional[bool] = Query(None, description="Filter active/inactive rules"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN])),
):
    """Retrieve municipal escalation rules with optional filtering."""
    query = db.query(EscalationRule)
    if department_id is not None:
        query = query.filter(EscalationRule.department_id == department_id)
    if category_id is not None:
        query = query.filter(EscalationRule.category_id == category_id)
    if is_active is not None:
        query = query.filter(EscalationRule.is_active == is_active)
    return query.order_by(EscalationRule.escalation_level.asc()).all()


@router.post(
    "/escalation/rules",
    response_model=EscalationRuleResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create escalation rule (Admin)",
)
def create_escalation_rule(
    rule_in: EscalationRuleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN])),
):
    """Create a new municipal escalation threshold rule."""
    if rule_in.department_id is not None:
        dept = db.query(Department).filter(Department.id == rule_in.department_id).first()
        if not dept:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Department with ID {rule_in.department_id} not found",
            )

    if rule_in.category_id is not None:
        cat = db.query(ComplaintCategory).filter(ComplaintCategory.id == rule_in.category_id).first()
        if not cat:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Category with ID {rule_in.category_id} not found",
            )
        if rule_in.department_id and cat.department_id != rule_in.department_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Category does not belong to specified department",
            )

    # Check for existing duplicate rule at same scope & level
    existing = (
        db.query(EscalationRule)
        .filter(
            EscalationRule.department_id == rule_in.department_id,
            EscalationRule.category_id == rule_in.category_id,
            EscalationRule.escalation_level == rule_in.escalation_level,
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"An escalation rule already exists for level {rule_in.escalation_level} in this scope",
        )

    rule = EscalationRule(
        department_id=rule_in.department_id,
        category_id=rule_in.category_id,
        escalation_level=rule_in.escalation_level,
        trigger_hours=rule_in.trigger_hours,
        target_role=rule_in.target_role.value if hasattr(rule_in.target_role, "value") else str(rule_in.target_role),
        is_active=rule_in.is_active,
    )
    db.add(rule)
    db.commit()
    db.refresh(rule)
    return rule


@router.put(
    "/escalation/rules/{rule_id}",
    response_model=EscalationRuleResponse,
    summary="Update escalation rule (Admin)",
)
def update_escalation_rule(
    rule_id: int,
    rule_in: EscalationRuleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN])),
):
    """Update escalation threshold hours, target role, or active status."""
    rule = db.query(EscalationRule).filter(EscalationRule.id == rule_id).first()
    if not rule:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Escalation rule not found")

    if rule_in.trigger_hours is not None:
        rule.trigger_hours = rule_in.trigger_hours
    if rule_in.target_role is not None:
        rule.target_role = (
            rule_in.target_role.value
            if hasattr(rule_in.target_role, "value")
            else str(rule_in.target_role)
        )
    if rule_in.is_active is not None:
        rule.is_active = rule_in.is_active

    db.commit()
    db.refresh(rule)
    return rule


@router.delete(
    "/escalation/rules/{rule_id}",
    response_model=MessageResponse,
    summary="Delete escalation rule (Admin)",
)
def delete_escalation_rule(
    rule_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN])),
):
    """Remove an escalation rule."""
    rule = db.query(EscalationRule).filter(EscalationRule.id == rule_id).first()
    if not rule:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Escalation rule not found")

    db.delete(rule)
    db.commit()
    return MessageResponse(message=f"Escalation rule #{rule_id} deleted successfully")


# ==========================================
# 2. ESCALATION EVENTS & COMPLAINT HISTORY
# ==========================================

@router.get(
    "/complaints/{complaint_id}/escalations",
    response_model=List[EscalationEventResponse],
    summary="Get complaint escalation history",
)
def get_complaint_escalations(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieve full escalation history for a complaint.
    Accessible to complaint owner (citizen) and authorized staff (officers, supervisors, admins).
    """
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found")

    # Access control
    if current_user.role == UserRole.CITIZEN.value and complaint.citizen_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this complaint's escalation history",
        )

    return get_complaint_escalation_history(db, complaint_id)


@router.post(
    "/complaints/{complaint_id}/escalate",
    response_model=Dict[str, Any],
    summary="Manually escalate complaint",
)
def manual_escalate_complaint(
    complaint_id: int,
    request: ManualEscalateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.OFFICER, UserRole.SUPERVISOR, UserRole.ADMIN])),
):
    """
    Manually escalate a complaint to the next authority level.
    Requires role of Officer, Supervisor, or Admin.
    """
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found")

    # Officers may only escalate within their assigned department
    if current_user.role == UserRole.OFFICER.value and current_user.department_id:
        if complaint.department_id != current_user.department_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Officers can only escalate complaints within their assigned department",
            )

    result = escalate_complaint(
        db=db,
        complaint_id=complaint_id,
        reason=request.reason,
        trigger_type="manual",
        actor=current_user,
    )

    if not result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Escalation failed: {result.get('reason')} - {result.get('detail', '')}",
        )

    return result


@router.post(
    "/complaints/{complaint_id}/extend-deadline",
    response_model=ComplaintResponse,
    summary="Extend complaint SLA deadline (Supervisor/Admin)",
)
def extend_complaint_deadline(
    complaint_id: int,
    request: DeadlineExtensionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.SUPERVISOR, UserRole.ADMIN])),
):
    """Authorized deadline extension with audit logging in status history."""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found")

    try:
        extend_deadline(
            complaint=complaint,
            additional_hours=request.additional_hours,
            reason=request.reason,
            changed_by=current_user,
            db=db,
        )
        db.commit()
        db.refresh(complaint)
        return complaint
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


# ==========================================
# 3. SUPERVISOR / AUTHORITY DASHBOARD QUEUE
# ==========================================

@router.get(
    "/escalation/assigned",
    response_model=List[ComplaintResponse],
    summary="View complaints escalated to caller",
)
def list_assigned_escalations(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.SUPERVISOR, UserRole.ADMIN, UserRole.OFFICER])),
):
    """
    List escalated complaints assigned to or under the supervision of the caller.
    """
    query = db.query(Complaint).filter(
        Complaint.status == ComplaintStatus.ESCALATED.value,
        Complaint.escalation_level > 0,
    )

    if current_user.role == UserRole.ADMIN.value:
        pass  # Admin sees all escalated
    elif current_user.role == UserRole.SUPERVISOR.value:
        if current_user.department_id:
            query = query.filter(
                or_(
                    Complaint.department_id == current_user.department_id,
                    Complaint.assigned_officer_id == current_user.id,
                )
            )
        else:
            query = query.filter(Complaint.assigned_officer_id == current_user.id)
    else:  # Officer
        query = query.filter(Complaint.assigned_officer_id == current_user.id)

    return query.order_by(desc(Complaint.updated_at)).offset(skip).limit(limit).all()


@router.post(
    "/escalation/{event_id}/acknowledge",
    response_model=EscalationEventResponse,
    summary="Acknowledge escalation event",
)
def acknowledge_escalation(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.SUPERVISOR, UserRole.ADMIN, UserRole.OFFICER])),
):
    """Acknowledge receipt and active handling of an escalated grievance."""
    event = acknowledge_escalation_event(db=db, event_id=event_id, user=current_user)
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Escalation event not found")
    return event


# ==========================================
# 4. SYSTEM / SCHEDULER MANAGEMENT
# ==========================================

@router.post(
    "/escalation/trigger-check",
    response_model=CheckerExecutionSummary,
    summary="Manually trigger overdue checker (Admin only)",
)
def trigger_overdue_checker_now(
    max_level: int = Query(3, ge=1, le=5),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.ADMIN])),
):
    """
    Manually run the overdue complaint checker immediately.
    Secured: Available strictly to Administrators.
    """
    return check_and_escalate_overdue_complaints(db=db, max_level=max_level)


@router.get(
    "/escalation/worker-status",
    response_model=WorkerStatusResponse,
    summary="Check escalation scheduler worker status (Admin only)",
)
def get_escalation_worker_status(
    current_user: User = Depends(require_roles([UserRole.ADMIN])),
):
    """Retrieve operational metrics of the background scheduler."""
    return get_worker_status()

