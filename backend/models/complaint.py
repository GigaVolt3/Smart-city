from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from backend.core.database import Base
from backend.models.enums import ComplaintStatus, ComplaintPriority


class Complaint(Base):
    __tablename__ = "complaints"

    id = Column(Integer, primary_key=True, index=True)
    complaint_number = Column(String(50), unique=True, index=True, nullable=False)
    citizen_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    assigned_officer_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    department_id = Column(Integer, ForeignKey("departments.id", ondelete="RESTRICT"), nullable=False)
    category_id = Column(Integer, ForeignKey("complaint_categories.id", ondelete="RESTRICT"), nullable=False)

    title = Column(String(150), nullable=False)
    description = Column(Text, nullable=False)
    ward = Column(String(50), nullable=False, index=True)
    address = Column(String(255), nullable=False)
    landmark = Column(String(150), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

    status = Column(String(30), default=ComplaintStatus.SUBMITTED.value, nullable=False, index=True)
    priority = Column(String(20), default=ComplaintPriority.MEDIUM.value, nullable=False, index=True)
    escalation_level = Column(Integer, default=0, nullable=False)

    due_at = Column(DateTime, nullable=False, index=True)
    resolved_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    citizen = relationship("User", foreign_keys=[citizen_id], back_populates="complaints_filed")
    assigned_officer = relationship("User", foreign_keys=[assigned_officer_id], back_populates="complaints_assigned")
    department = relationship("Department", back_populates="complaints")
    category = relationship("ComplaintCategory", back_populates="complaints")
    attachments = relationship("ComplaintAttachment", back_populates="complaint", cascade="all, delete-orphan")
    status_history = relationship("StatusHistory", back_populates="complaint", cascade="all, delete-orphan", order_by="StatusHistory.created_at.desc()")
    escalation_events = relationship("EscalationEvent", back_populates="complaint", cascade="all, delete-orphan", order_by="EscalationEvent.created_at.desc()")


class ComplaintAttachment(Base):
    __tablename__ = "complaint_attachments"

    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(Integer, ForeignKey("complaints.id", ondelete="CASCADE"), nullable=False)
    file_path = Column(String(255), nullable=False)
    file_name = Column(String(255), nullable=False)
    file_size = Column(Integer, nullable=False)
    mime_type = Column(String(100), nullable=False)
    uploaded_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    complaint = relationship("Complaint", back_populates="attachments")
