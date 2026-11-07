from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


# 1. Classification Schemas
class ClassificationRequest(BaseModel):
    title: str = Field(..., min_length=3, max_length=150, description="Complaint title")
    description: str = Field(..., min_length=5, description="Detailed complaint description")
    department_hint_id: Optional[int] = Field(None, description="Optional department filter")


class ClassificationCandidate(BaseModel):
    category_id: int
    category_code: str
    category_name: str
    department_id: int
    department_name: Optional[str] = None
    confidence: float


class ClassificationResponse(BaseModel):
    category_id: Optional[int] = None
    category_code: Optional[str] = None
    category_name: Optional[str] = None
    department_id: Optional[int] = None
    department_code: Optional[str] = None
    department_name: Optional[str] = None
    confidence: float
    suggested_priority: str
    matched_keywords: List[str] = []
    candidates: List[ClassificationCandidate] = []


# 2. Duplicate Detection Schemas
class DuplicateCheckRequest(BaseModel):
    title: str = Field(..., min_length=3, max_length=150)
    description: str = Field(..., min_length=5)
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0)
    category_id: Optional[int] = None
    department_id: Optional[int] = None
    radius_meters: Optional[float] = Field(150.0, ge=10.0, le=5000.0)
    similarity_threshold: Optional[float] = Field(0.65, ge=0.1, le=1.0)
    exclude_complaint_id: Optional[int] = None
    active_only: bool = True
    days_lookback: int = Field(30, ge=1, le=365)


class DuplicateMatch(BaseModel):
    complaint_id: int
    complaint_number: str
    title: str
    status: str
    ward: Optional[str] = None
    distance_meters: Optional[float] = None
    text_similarity: float
    geo_similarity: Optional[float] = None
    overall_similarity: float
    created_at: str


class DuplicateCheckResponse(BaseModel):
    is_duplicate: bool
    confidence: float
    primary_complaint_id: Optional[int] = None
    matches: List[DuplicateMatch] = []
    total_candidates_analyzed: int


# 3. Priority Scoring Schemas
class PriorityScoreRequest(BaseModel):
    title: str = Field(..., min_length=3, max_length=150)
    description: str = Field(..., min_length=5)
    category_id: Optional[int] = None
    ward: Optional[str] = None
    address: Optional[str] = None
    landmark: Optional[str] = None
    duplicate_count: int = Field(0, ge=0)


class PriorityScoreResponse(BaseModel):
    priority_score: int
    priority_level: str
    recommended_sla_hours: int
    factors: List[str]
    score_breakdown: Dict[str, int]


# 4. Hotspot Detection Schemas
class HotspotCentroid(BaseModel):
    latitude: float
    longitude: float


class HotspotCluster(BaseModel):
    hotspot_id: str
    centroid: HotspotCentroid
    radius_meters: float
    total_complaints: int
    open_complaints: int
    resolved_complaints: int
    unresolved_rate: float
    recurrence_score: int
    severity_tier: str
    predominant_category: Dict[str, Any]
    predominant_department: Dict[str, Any]
    affected_wards: List[str]
    first_reported_at: str
    last_reported_at: str
    avg_recurrence_interval_days: float
    sample_complaints: List[Dict[str, Any]]


class HotspotsSummary(BaseModel):
    most_critical_ward: Optional[str] = None
    top_recurring_category: Optional[str] = None
    avg_cluster_size: float = 0.0


class HotspotsResponse(BaseModel):
    total_complaints_analyzed: int
    total_hotspots: int
    hotspots: List[HotspotCluster]
    geojson: Dict[str, Any]
    summary: HotspotsSummary


# 5. Image Comparison Schemas
class ImageComparisonResponse(BaseModel):
    is_verified: bool
    verification_status: str
    resolution_score: float
    confidence: float
    metrics: Dict[str, Any]
    explanation: str
