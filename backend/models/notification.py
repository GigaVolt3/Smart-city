from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text

from backend.core.database import Base


class Notification(Base):
    """In-app notification delivered to a specific user."""

    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    complaint_id = Column(
        Integer, ForeignKey("complaints.id", ondelete="CASCADE"), nullable=True, index=True
    )
    notification_type = Column(String(40), nullable=False, default="system")
    title = Column(String(160), nullable=False)
    message = Column(Text, nullable=False)
    is_read = Column(Boolean, default=False, nullable=False, index=True)
    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True
    )
