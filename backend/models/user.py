from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from backend.core.database import Base
from backend.models.enums import UserRole


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(120), unique=True, index=True, nullable=False)
    full_name = Column(String(100), nullable=False)
    phone_number = Column(String(20), nullable=True)
    role = Column(String(20), default=UserRole.CITIZEN.value, nullable=False)
    department_id = Column(Integer, ForeignKey("departments.id", ondelete="SET NULL"), nullable=True)
    ward = Column(String(50), nullable=True)
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    department = relationship("Department", back_populates="users")
    complaints_filed = relationship("Complaint", back_populates="citizen", foreign_keys="Complaint.citizen_id")
    complaints_assigned = relationship("Complaint", back_populates="assigned_officer", foreign_keys="Complaint.assigned_officer_id")
    status_updates = relationship("StatusHistory", back_populates="changed_by")
