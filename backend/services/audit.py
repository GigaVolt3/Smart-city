"""Append-only audit trail helper."""

from typing import Optional

from sqlalchemy.orm import Session

from backend.models.audit import AuditEvent
from backend.models.user import User


def record_audit(
    db: Session,
    *,
    user: Optional[User],
    action: str,
    resource_type: str,
    resource_id: Optional[object] = None,
    details: Optional[str] = None,
    ip_address: Optional[str] = None,
) -> AuditEvent:
    """Queue an audit event. The caller owns the transaction."""
    event = AuditEvent(
        user_id=user.id if user else None,
        action=action,
        resource_type=resource_type,
        resource_id=str(resource_id) if resource_id is not None else None,
        details=details,
        ip_address=ip_address,
    )
    db.add(event)
    return event
