from typing import List, Optional

from pydantic import BaseModel


class KpiSummary(BaseModel):
    total: int
    open: int
    resolved: int
    rejected: int
    escalated: int
    critical_open: int
    sla_breached: int
    new_in_period: int
    resolved_in_period: int
    resolution_rate: float
    sla_compliance_rate: float
    avg_resolution_hours: float


class StatusCount(BaseModel):
    status: str
    count: int


class PriorityCount(BaseModel):
    priority: str
    count: int


class TrendPoint(BaseModel):
    date: str
    submitted: int
    resolved: int


class DepartmentPerformance(BaseModel):
    id: int
    name: str
    code: str
    total: int
    open: int
    resolved: int
    escalated: int
    breached: int
    sla_compliance_rate: float
    avg_resolution_hours: float


class CategoryCount(BaseModel):
    id: int
    name: str
    department: Optional[str] = None
    count: int


class WardCount(BaseModel):
    ward: str
    total: int
    open: int
    breached: int


class SlaSummary(BaseModel):
    on_track: int
    at_risk: int
    breached: int
    compliance_rate: float


class ActivityItem(BaseModel):
    id: int
    complaint_id: int
    complaint_number: str
    title: str
    previous_status: Optional[str] = None
    new_status: str
    comments: Optional[str] = None
    actor: str
    created_at: str


class MapPoint(BaseModel):
    id: int
    complaint_number: str
    title: str
    status: str
    priority: str
    latitude: float
    longitude: float
    ward: str
    category: str


class MyCounters(BaseModel):
    assigned: int
    filed: int
    unread_notifications: int


class AnalyticsOverview(BaseModel):
    role: str
    days: int
    kpis: KpiSummary
    status_breakdown: List[StatusCount]
    priority_breakdown: List[PriorityCount]
    trend: List[TrendPoint]
    departments: List[DepartmentPerformance]
    categories: List[CategoryCount]
    wards: List[WardCount]
    sla: SlaSummary
    recent_activity: List[ActivityItem]
    map_points: List[MapPoint]
    my: MyCounters
