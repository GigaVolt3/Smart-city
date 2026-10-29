from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from backend.core.database import Base


class EscalationRule(Base):
    __tablename__ = "escalation_rules"

    id = Column(Integer, primary_key=True, index=True)
    department_id = Column(Integer, ForeignKey("departments.id", ondelete="CASCADE"), nullable=True)
    category_id = Column(Integer, ForeignKey("complaint_categories.id", ondelete="CASCADE"), nullable=True)
    escalation_level = Column(Integer, nullable=False)  # 1: Ward Officer, 2: Dept Supervisor, 3: Municipal Commissioner
    trigger_hours = Column(Integer, nullable=False)     # hours past deadline or SLA to trigger
    target_role = Column(String(50), nullable=False)    # e.g., "supervisor", "admin"
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class EscalationEvent(Base):
    __tablename__ = "escalation_events"

    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(Integer, ForeignKey("complaints.id", ondelete="CASCADE"), nullable=False)
    from_level = Column(Integer, nullable=False)
    to_level = Column(Integer, nullable=False)
    reason = Column(Text, nullable=False)
    escalated_to_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    complaint = relationship("Complaint", back_populates="escalation_events")
    escalated_to = relationship("User", foreign_keys=[escalated_to_id])
