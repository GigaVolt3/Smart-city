from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict
from backend.models.enums import ComplaintPriority


class CategoryBase(BaseModel):
    department_id: int
    name: str = Field(..., min_length=2, max_length=100)
    code: str = Field(..., min_length=2, max_length=50)
    description: Optional[str] = Field(None, max_length=255)
    sla_hours: int = Field(default=48, ge=1, le=720)
    priority_default: ComplaintPriority = ComplaintPriority.MEDIUM
    is_active: bool = True


class CategoryCreate(CategoryBase):
    pass


class CategoryUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    description: Optional[str] = Field(None, max_length=255)
    sla_hours: Optional[int] = Field(None, ge=1, le=720)
    priority_default: Optional[ComplaintPriority] = None
    is_active: Optional[bool] = None


class CategoryResponse(CategoryBase):
    id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

