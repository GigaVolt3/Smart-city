from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field, ConfigDict
from backend.models.enums import ComplaintStatus, ComplaintPriority
from backend.schemas.user import UserResponse
from backend.schemas.department import DepartmentResponse
from backend.schemas.category import CategoryResponse


class ComplaintCreate(BaseModel):
    department_id: int
    category_id: int
    title: str = Field(..., min_length=5, max_length=150)
    description: str = Field(..., min_length=10)
    ward: str = Field(..., min_length=1, max_length=50)
    address: str = Field(..., min_length=5, max_length=255)
    landmark: Optional[str] = Field(None, max_length=150)
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0)
    priority: Optional[ComplaintPriority] = None


class ComplaintStatusUpdate(BaseModel):
    status: ComplaintStatus
    comments: Optional[str] = Field(None, max_length=500)
    assigned_officer_id: Optional[int] = None


class AttachmentResponse(BaseModel):
    id: int
    file_name: str
    file_path: str
    file_size: int
    mime_type: str
    uploaded_at: datetime

    model_config = ConfigDict(from_attributes=True)


class StatusHistoryResponse(BaseModel):
    id: int
    complaint_id: int
    previous_status: Optional[str] = None
    new_status: str
    changed_by_id: Optional[int] = None
    comments: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ComplaintResponse(BaseModel):
    id: int
    complaint_number: str
    citizen_id: int
    assigned_officer_id: Optional[int] = None
    department_id: int
    category_id: int
    title: str
    description: str
    ward: str
    address: str
    landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    status: ComplaintStatus
    priority: ComplaintPriority
    escalation_level: int
    due_at: datetime
    resolved_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ComplaintDetailResponse(ComplaintResponse):
    citizen: Optional[UserResponse] = None
    assigned_officer: Optional[UserResponse] = None
    department: Optional[DepartmentResponse] = None
    category: Optional[CategoryResponse] = None
    attachments: List[AttachmentResponse] = []
    status_history: List[StatusHistoryResponse] = []

    model_config = ConfigDict(from_attributes=True)

