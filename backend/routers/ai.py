from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, status
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.deps import get_current_user, require_roles
from backend.models.user import User
from backend.models.complaint import Complaint, ComplaintAttachment
from backend.models.enums import UserRole
from backend.ai.classifier import CivicClassifier
from backend.ai.duplicate_detector import DuplicateDetector
from backend.ai.priority_scorer import CivicPriorityScorer
from backend.ai.hotspot_detector import CivicHotspotDetector
from backend.ai.image_comparator import CivicImageComparator
from backend.schemas.ai import (
    ClassificationRequest,
    ClassificationResponse,
    DuplicateCheckRequest,
    DuplicateCheckResponse,
    PriorityScoreRequest,
    PriorityScoreResponse,
    HotspotsResponse,
    ImageComparisonResponse,
)

router = APIRouter(prefix="/ai", tags=["AI Engine"])

# AI service singletons
classifier = CivicClassifier()
duplicate_detector = DuplicateDetector()
priority_scorer = CivicPriorityScorer()
hotspot_detector = CivicHotspotDetector()
image_comparator = CivicImageComparator()


# -------------------------------------------------------------
# 1. Complaint Classification
# -------------------------------------------------------------
@router.post("/classify", response_model=ClassificationResponse)
def classify_complaint(
    payload: ClassificationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    AI Task 1: Complaint Classification.
    Analyzes unstructured grievance title and description to predict the appropriate
    municipal Department, Category, and suggested Priority with confidence scoring.
    """
    result = classifier.classify(
        title=payload.title,
        description=payload.description,
        db=db,
        department_hint_id=payload.department_hint_id,
    )
    return result


# -------------------------------------------------------------
# 2. Duplicate Complaint Detection
# -------------------------------------------------------------
@router.post("/check-duplicates", response_model=DuplicateCheckResponse)
def check_duplicate_complaints(
    payload: DuplicateCheckRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    AI Task 2: Duplicate Complaint Detection using Text and GPS.
    Fuses spatial Haversine distance with TF-IDF cosine text similarity and category alignment
    to detect duplicate or redundant tickets within a geographic radius.
    """
    result = duplicate_detector.find_duplicates(
        title=payload.title,
        description=payload.description,
        latitude=payload.latitude,
        longitude=payload.longitude,
        db=db,
        category_id=payload.category_id,
        department_id=payload.department_id,
        radius_meters=payload.radius_meters,
        similarity_threshold=payload.similarity_threshold,
        exclude_complaint_id=payload.exclude_complaint_id,
        active_only=payload.active_only,
        days_lookback=payload.days_lookback,
    )
    return result


# -------------------------------------------------------------
# 3. AI-Based Complaint Priority Scoring
# -------------------------------------------------------------
@router.post("/score-priority", response_model=PriorityScoreResponse)
def score_complaint_priority(
    payload: PriorityScoreRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    AI Task 3: AI-based Complaint Priority Scoring.
    Computes an explainable 0-100 urgency score and determines SLA tier (CRITICAL, HIGH, MEDIUM, LOW)
    based on public safety hazards, critical infrastructure proximity, and crowd surge velocity.
    """
    result = priority_scorer.score_complaint(
        title=payload.title,
        description=payload.description,
        category_id=payload.category_id,
        ward=payload.ward,
        address=payload.address,
        landmark=payload.landmark,
        duplicate_count=payload.duplicate_count,
        db=db,
    )
    return result


# -------------------------------------------------------------
# 4. Recurring Issue Hotspot Detection
# -------------------------------------------------------------
@router.get("/hotspots", response_model=HotspotsResponse)
def get_recurring_hotspots(
    department_id: Optional[int] = Query(None, description="Filter by department"),
    category_id: Optional[int] = Query(None, description="Filter by category"),
    ward: Optional[str] = Query(None, description="Filter by ward name"),
    days_back: int = Query(90, ge=1, le=365, description="Lookback window in days"),
    cluster_radius_meters: float = Query(200.0, ge=20.0, le=2000.0, description="DBSCAN radius in meters"),
    min_complaints: int = Query(2, ge=2, le=50, description="Minimum complaints to form a hotspot cluster"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    AI Task 4: Recurring Issue Hotspot Detection.
    Runs DBSCAN spatial clustering over geographic coordinates to discover chronic civic hotspots,
    frequent infrastructure breakdown zones, and repeated dumping sites with GeoJSON export.
    """
    result = hotspot_detector.detect_hotspots(
        db=db,
        department_id=department_id,
        category_id=category_id,
        ward=ward,
        days_back=days_back,
        cluster_radius_meters=cluster_radius_meters,
        min_complaints=min_complaints,
    )
    return result


# -------------------------------------------------------------
# 5. Before-and-After Image Comparison
# -------------------------------------------------------------
@router.post("/compare-images", response_model=ImageComparisonResponse)
async def compare_resolution_images(
    before_image: UploadFile = File(..., description="Original complaint image submitted by citizen"),
    after_image: UploadFile = File(..., description="Resolution proof image uploaded by officer"),
    current_user: User = Depends(require_roles([UserRole.OFFICER, UserRole.SUPERVISOR, UserRole.ADMIN])),
):
    """
    AI Task 5: Before-and-After Image Comparison.
    Uses computer vision (SSIM, color histogram correlation, edge energy, perceptual hashing)
    to verify actual work resolution and flag fraud (identical re-uploads, dark/dummy photos).
    """
    before_bytes = await before_image.read()
    after_bytes = await after_image.read()

    result = image_comparator.compare(before_bytes, after_bytes)
    return result


@router.post("/verify-complaint-resolution/{complaint_id}", response_model=ImageComparisonResponse)
async def verify_complaint_resolution(
    complaint_id: int,
    after_image: UploadFile = File(..., description="Officer resolution photo"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.OFFICER, UserRole.SUPERVISOR, UserRole.ADMIN])),
):
    """
    AI Task 5 Integration: Compare officer's resolution photo directly with complaint's original photo attachment.
    """
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Complaint with ID {complaint_id} not found",
        )

    # Check for original image attachment
    first_attachment = db.query(ComplaintAttachment).filter(
        ComplaintAttachment.complaint_id == complaint_id,
        ComplaintAttachment.mime_type.like("image/%")
    ).first()

    if not first_attachment:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Complaint has no original image attachment to compare against",
        )

    try:
        with open(first_attachment.file_path, "rb") as f:
            before_bytes = f.read()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Could not read complaint attachment from disk: {str(e)}",
        )

    after_bytes = await after_image.read()
    return image_comparator.compare(before_bytes, after_bytes)
