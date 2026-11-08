import logging
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session

from backend.models.notification import Notification

logger = logging.getLogger("civicai.notifications")


def create_notification(
    db: Session,
    user_id: int,
    title: str,
    message: str,
    complaint_id: Optional[int] = None,
    notification_type: str = "escalation",
) -> Notification:
    """Create an in-app notification entry for an authority or citizen."""
    notification = Notification(
        user_id=user_id,
        complaint_id=complaint_id,
        title=title,
        message=message,
        notification_type=notification_type,
        is_read=False,
        created_at=datetime.now(timezone.utc),
    )
    db.add(notification)
    return notification


def dispatch_notification_safe(
    db: Session,
    user_id: Optional[int],
    title: str,
    message: str,
    complaint_id: Optional[int] = None,
    notification_type: str = "escalation",
) -> Optional[Notification]:
    """
    Safely dispatch an in-app notification.
    If user_id is missing or creation fails, logs a warning without breaking the transaction.
    """
    if not user_id:
        logger.warning(
            f"Skipped notification dispatch for complaint {complaint_id}: recipient user_id is missing."
        )
        return None

    try:
        notification = create_notification(
            db=db,
            user_id=user_id,
            title=title,
            message=message,
            complaint_id=complaint_id,
            notification_type=notification_type,
        )
        logger.info(f"Notification queued for User {user_id}: '{title}' (Complaint #{complaint_id})")
        return notification
    except Exception as exc:
        logger.error(f"Failed to create notification for User {user_id}: {exc}", exc_info=True)
        return None


def get_user_notifications(
    db: Session,
    user_id: int,
    unread_only: bool = False,
    skip: int = 0,
    limit: int = 50,
) -> List[Notification]:
    """List notifications for a specific user, sorted newest first."""
    query = db.query(Notification).filter(Notification.user_id == user_id)
    if unread_only:
        query = query.filter(Notification.is_read.is_(False))
    return query.order_by(Notification.created_at.desc()).offset(skip).limit(limit).all()


def mark_notification_read(db: Session, notification_id: int, user_id: int) -> Optional[Notification]:
    """Mark a single notification as read if it belongs to the user."""
    notification = (
        db.query(Notification)
        .filter(Notification.id == notification_id, Notification.user_id == user_id)
        .first()
    )
    if notification and not notification.is_read:
        notification.is_read = True
        notification.read_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(notification)
    return notification


def mark_all_notifications_read(db: Session, user_id: int) -> int:
    """Mark all unread notifications for a user as read."""
    now = datetime.now(timezone.utc)
    count = (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.is_read.is_(False))
        .update({Notification.is_read: True, Notification.read_at: now}, synchronize_session=False)
    )
    db.commit()
    return count

