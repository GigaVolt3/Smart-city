"""Notification fan-out helpers."""

from typing import Iterable, Optional

from sqlalchemy.orm import Session

from backend.models.notification import Notification


def notify_users(
    db: Session,
    user_ids: Iterable[Optional[int]],
    *,
    title: str,
    message: str,
    notification_type: str = "system",
    complaint_id: Optional[int] = None,
) -> list[Notification]:
    """Create one notification per unique recipient.

    The caller owns the transaction and is responsible for committing.
    """
    created: list[Notification] = []
    seen: set[int] = set()

    for user_id in user_ids:
        if user_id is None or user_id in seen:
            continue
        seen.add(user_id)
        notification = Notification(
            user_id=int(user_id),
            complaint_id=complaint_id,
            notification_type=notification_type,
            title=title,
            message=message,
            is_read=False,
        )
        db.add(notification)
        created.append(notification)

    return created
