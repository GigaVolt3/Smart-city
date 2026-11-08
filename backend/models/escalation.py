from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, Float, Boolean, DateTime, ForeignKey, UniqueConstraint
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
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    department = relationship("Department")
    category = relationship("ComplaintCategory")


class EscalationEvent(Base):
    __tablename__ = "escalation_events"
    __table_args__ = (
        UniqueConstraint("complaint_id", "to_level", name="uq_escalation_event_complaint_level"),
    )

    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(Integer, ForeignKey("complaints.id", ondelete="CASCADE"), nullable=False)
    from_level = Column(Integer, nullable=False)
    to_level = Column(Integer, nullable=False)
    reason = Column(Text, nullable=False)
    escalated_from_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    escalated_to_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    trigger_type = Column(String(20), default="automatic", nullable=False)  # "automatic" or "manual"
    deadline_exceeded_hours = Column(Float, nullable=True)
    acknowledged_at = Column(DateTime, nullable=True)
    acknowledged_by_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    complaint = relationship("Complaint", back_populates="escalation_events")
    escalated_from = relationship("User", foreign_keys=[escalated_from_id])
    escalated_to = relationship("User", foreign_keys=[escalated_to_id])
    acknowledged_by = relationship("User", foreign_keys=[acknowledged_by_id])
