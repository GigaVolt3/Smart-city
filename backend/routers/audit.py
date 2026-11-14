from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session, joinedload

from backend.core.database import get_db
from backend.core.deps import require_roles
from backend.models.audit import AuditEvent
from backend.models.enums import UserRole
from backend.models.user import User
from backend.schemas.audit import AuditEventResponse

router = APIRouter(prefix="/audit", tags=["Audit"])


@router.get("", response_model=List[AuditEventResponse])
def list_audit_events(
    action: Optional[str] = Query(None, description="Filter by action prefix"),
    resource_type: Optional[str] = Query(None),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    _admin: User = Depends(require_roles([UserRole.ADMIN])),
):
    """Immutable audit trail (municipal administrators only)."""
    query = db.query(AuditEvent).options(joinedload(AuditEvent.user))
    if action:
        query = query.filter(AuditEvent.action.like(f"{action}%"))
    if resource_type:
        query = query.filter(AuditEvent.resource_type == resource_type)

    events = (
        query.order_by(AuditEvent.created_at.desc()).offset(skip).limit(limit).all()
    )
    return [
        AuditEventResponse(
            id=event.id,
            user_id=event.user_id,
            user_name=event.user.full_name if event.user else "System",
            action=event.action,
            resource_type=event.resource_type,
            resource_id=event.resource_id,
            details=event.details,
            ip_address=event.ip_address,
            created_at=event.created_at,
        )
        for event in events
    ]
