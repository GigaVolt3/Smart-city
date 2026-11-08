from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field, ConfigDict
from backend.models.enums import UserRole


class EscalationRuleBase(BaseModel):
    department_id: Optional[int] = Field(None, description="Department ID, or null for municipal global rule")
    category_id: Optional[int] = Field(None, description="Category ID, or null for department-wide rule")
    escalation_level: int = Field(..., ge=1, le=5, description="Target escalation level (1: Officer, 2: Supervisor, 3: Admin)")
    trigger_hours: int = Field(..., ge=1, le=720, description="Hours threshold or extension period")
    target_role: UserRole = Field(..., description="Role responsible at this level")
    is_active: bool = Field(True, description="Whether this rule is active")


class EscalationRuleCreate(EscalationRuleBase):
    pass


class EscalationRuleUpdate(BaseModel):
    trigger_hours: Optional[int] = Field(None, ge=1, le=720)
    target_role: Optional[UserRole] = None
    is_active: Optional[bool] = None


class EscalationRuleResponse(EscalationRuleBase):
    id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class EscalationEventResponse(BaseModel):
    id: int
    complaint_id: int
    from_level: int
    to_level: int
    reason: str
    escalated_from_id: Optional[int] = None
    escalated_to_id: Optional[int] = None
    trigger_type: str
    deadline_exceeded_hours: Optional[float] = None
    acknowledged_at: Optional[datetime] = None
    acknowledged_by_id: Optional[int] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ManualEscalateRequest(BaseModel):
    reason: str = Field(..., min_length=5, max_length=500, description="Reason for manual escalation")


class DeadlineExtensionRequest(BaseModel):
    additional_hours: int = Field(..., ge=1, le=720, description="Number of additional hours to add to SLA")
    reason: str = Field(..., min_length=5, max_length=500, description="Justification for extending SLA deadline")


class CheckerExecutionSummary(BaseModel):
    timestamp: str
    checked: int
    escalated: int
    skipped: int
    failed: int
    duration_seconds: float
    details: List[Dict[str, Any]] = []


class WorkerStatusResponse(BaseModel):
    running: bool
    interval_seconds: int
    dev_mode: bool
    next_run_time: Optional[str] = None
    last_run_summary: Optional[Dict[str, Any]] = None

