from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.deps import get_current_user
from backend.models.notification import Notification
from backend.models.user import User
from backend.schemas.notification import (
    NotificationListResponse,
    NotificationResponse,
    UnreadCountResponse,
)

router = APIRouter(prefix="/notifications", tags=["Notifications"])


def _unread_count(db: Session, user_id: int) -> int:
    return (
        db.query(Notification)
        .filter(
            Notification.user_id == user_id,
            Notification.is_read.is_(False),
        )
        .count()
    )


@router.get("", response_model=NotificationListResponse)
def list_notifications(
    unread_only: bool = Query(False),
    notification_type: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List the signed-in user's notifications, newest first."""
    query = db.query(Notification).filter(Notification.user_id == current_user.id)
    if unread_only:
        query = query.filter(Notification.is_read.is_(False))
    if notification_type:
        query = query.filter(Notification.notification_type == notification_type)

    total = query.count()
    items = (
        query.order_by(Notification.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return NotificationListResponse(
        items=[NotificationResponse.model_validate(item) for item in items],
        total=total,
        unread_count=_unread_count(db, current_user.id),
    )


@router.get("/unread-count", response_model=UnreadCountResponse)
def get_unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return UnreadCountResponse(unread_count=_unread_count(db, current_user.id))


@router.put("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notification = (
        db.query(Notification)
        .filter(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
        )
        .first()
    )
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found"
        )
    notification.is_read = True
    db.commit()
    db.refresh(notification)
    return notification


@router.post("/read-all", response_model=UnreadCountResponse)
def mark_all_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read.is_(False),
    ).update({Notification.is_read: True}, synchronize_session=False)
    db.commit()
    return UnreadCountResponse(unread_count=0)


@router.delete("/{notification_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_notification(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notification = (
        db.query(Notification)
        .filter(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
        )
        .first()
    )
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found"
        )
    db.delete(notification)
    db.commit()
    return None
