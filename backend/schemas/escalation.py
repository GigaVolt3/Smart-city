from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class EscalationEventResponse(BaseModel):
    id: int
    complaint_id: int
    from_level: int
    to_level: int
    reason: str
    escalated_to_id: Optional[int] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class EscalationEventDetail(EscalationEventResponse):
    complaint_number: Optional[str] = None
    complaint_title: Optional[str] = None
    department: Optional[str] = None
    escalated_to_name: Optional[str] = None


class EscalationRuleCreate(BaseModel):
    department_id: Optional[int] = None
    category_id: Optional[int] = None
    escalation_level: int = Field(..., ge=1, le=5)
    trigger_hours: int = Field(..., ge=0, le=720)
    target_role: str = Field(..., pattern="^(officer|supervisor|admin)$")


class EscalationRuleResponse(BaseModel):
    id: int
    department_id: Optional[int] = None
    category_id: Optional[int] = None
    escalation_level: int
    trigger_hours: int
    target_role: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class EscalationRunResponse(BaseModel):
    escalated: int
    events: list[EscalationEventResponse]


class EscalationSummary(BaseModel):
    total_events: int
    open_escalated: int
    by_level: dict[str, int]
    by_department: list[dict]
