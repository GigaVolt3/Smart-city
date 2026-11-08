from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.deps import get_current_user
from backend.models.user import User
from backend.models.notification import Notification
from backend.schemas.notification import NotificationResponse, UnreadCountResponse
from backend.schemas.common import MessageResponse
from backend.services.notification_service import (
    get_user_notifications,
    mark_notification_read,
    mark_all_notifications_read,
)

router = APIRouter(prefix="/notifications", tags=["In-App Notifications"])


@router.get("", response_model=List[NotificationResponse], summary="List user notifications")
def list_notifications(
    unread_only: bool = Query(False, description="Filter for unread notifications only"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve in-app notifications for the authenticated user."""
    return get_user_notifications(
        db=db,
        user_id=current_user.id,
        unread_only=unread_only,
        skip=skip,
        limit=limit,
    )


@router.get("/unread-count", response_model=UnreadCountResponse, summary="Get unread notification count")
def get_unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve count of unread alerts for current user."""
    count = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id, Notification.is_read.is_(False))
        .count()
    )
    return UnreadCountResponse(unread_count=count)


@router.patch("/{notification_id}/read", response_model=NotificationResponse, summary="Mark notification as read")
def mark_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark a specific notification as read."""
    notification = mark_notification_read(db=db, notification_id=notification_id, user_id=current_user.id)
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found or access denied",
        )
    return notification


@router.post("/mark-all-read", response_model=MessageResponse, summary="Mark all notifications as read")
def mark_all_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark all unread notifications for current user as read."""
    count = mark_all_notifications_read(db=db, user_id=current_user.id)
    return MessageResponse(message=f"Marked {count} notifications as read")

