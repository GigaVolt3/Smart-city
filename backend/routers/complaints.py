from datetime import datetime, timedelta, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc

from backend.core.database import get_db
from backend.core.deps import get_current_user, require_roles
from backend.models.complaint import Complaint, ComplaintAttachment
from backend.models.status_history import StatusHistory
from backend.models.escalation import EscalationEvent
from backend.models.category import ComplaintCategory
from backend.models.department import Department
from backend.models.user import User
from backend.models.enums import UserRole, ComplaintStatus, ComplaintPriority
from backend.schemas.complaint import (
    ComplaintCreate,
    ComplaintStatusUpdate,
    ComplaintResponse,
    ComplaintDetailResponse,
    StatusHistoryResponse,
)

router = APIRouter(prefix="/complaints", tags=["Complaints"])


def _generate_complaint_number(db: Session) -> str:
    """Generate sequential unique complaint reference number: CIVIC-YYYY-XXXX."""
    current_year = datetime.now(timezone.utc).year
    prefix = f"CIVIC-{current_year}-"
    # Find max complaint id or count for this year
    count = db.query(Complaint).filter(Complaint.complaint_number.like(f"{prefix}%")).count()
    return f"{prefix}{count + 1:04d}"


@router.post("", response_model=ComplaintResponse, status_code=status.HTTP_201_CREATED)
def create_complaint(
    complaint_in: ComplaintCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Submit a new civic complaint.
    Auto-assigns unique complaint_number, computes SLA due_at, and records initial status history.
    """
    # Verify department exists
    dept = db.query(Department).filter(Department.id == complaint_in.department_id).first()
    if not dept:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Department with ID {complaint_in.department_id} not found",
        )

    # Verify category exists and belongs to department
    category = db.query(ComplaintCategory).filter(
        ComplaintCategory.id == complaint_in.category_id,
        ComplaintCategory.department_id == complaint_in.department_id,
    ).first()
    if not category:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Category not found or does not belong to the selected department",
        )

    # Calculate SLA due date
    now = datetime.now(timezone.utc)
    due_at = now + timedelta(hours=category.sla_hours)

    # Priority determination
    priority = complaint_in.priority.value if complaint_in.priority else category.priority_default

    complaint_number = _generate_complaint_number(db)

    complaint = Complaint(
        complaint_number=complaint_number,
        citizen_id=current_user.id,
        department_id=complaint_in.department_id,
        category_id=complaint_in.category_id,
        title=complaint_in.title,
        description=complaint_in.description,
        ward=complaint_in.ward,
        address=complaint_in.address,
        landmark=complaint_in.landmark,
        latitude=complaint_in.latitude,
        longitude=complaint_in.longitude,
        status=ComplaintStatus.SUBMITTED.value,
        priority=priority,
        escalation_level=0,
        due_at=due_at,
        created_at=now,
        updated_at=now,
    )
    db.add(complaint)
    db.flush()  # get complaint.id

    # Add initial status history entry
    initial_history = StatusHistory(
        complaint_id=complaint.id,
        previous_status=None,
        new_status=ComplaintStatus.SUBMITTED.value,
        changed_by_id=current_user.id,
        comments="Grievance submitted by citizen",
        created_at=now,
    )
    db.add(initial_history)
    db.commit()
    db.refresh(complaint)

    return complaint


@router.get("", response_model=List[ComplaintResponse])
def list_complaints(
    status: Optional[ComplaintStatus] = Query(None, description="Filter by status"),
    department_id: Optional[int] = Query(None, description="Filter by department"),
    category_id: Optional[int] = Query(None, description="Filter by category"),
    priority: Optional[ComplaintPriority] = Query(None, description="Filter by priority"),
    ward: Optional[str] = Query(None, description="Filter by ward"),
    search: Optional[str] = Query(None, description="Search keyword in title, description, or complaint number"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    List complaints according to caller role:
    - Citizens: only view their own complaints
    - Officers: view complaints in their assigned department or all
    - Supervisors / Admins: view all complaints
    """
    query = db.query(Complaint)

    # Role-based scoping
    if current_user.role == UserRole.CITIZEN.value:
        query = query.filter(Complaint.citizen_id == current_user.id)
    elif current_user.role == UserRole.OFFICER.value and current_user.department_id:
        query = query.filter(
            or_(
                Complaint.department_id == current_user.department_id,
                Complaint.assigned_officer_id == current_user.id,
            )
        )

    # Apply filters
    if status is not None:
        query = query.filter(Complaint.status == status.value)
    if department_id is not None:
        query = query.filter(Complaint.department_id == department_id)
    if category_id is not None:
        query = query.filter(Complaint.category_id == category_id)
    if priority is not None:
        query = query.filter(Complaint.priority == priority.value)
    if ward is not None:
        query = query.filter(Complaint.ward.ilike(f"%{ward}%"))
    if search:
        search_filter = f"%{search}%"
        query = query.filter(
            or_(
                Complaint.title.ilike(search_filter),
                Complaint.description.ilike(search_filter),
                Complaint.complaint_number.ilike(search_filter),
            )
        )

    return query.order_by(desc(Complaint.created_at)).offset(skip).limit(limit).all()


@router.get("/{complaint_id}", response_model=ComplaintDetailResponse)
def get_complaint(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Get detailed complaint record including attachments, citizen, department, and status history.
    Citizens can only view their own grievances.
    """
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    # Citizens can only access their own complaints
    if current_user.role == UserRole.CITIZEN.value and complaint.citizen_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this complaint",
        )

    return complaint


@router.put("/{complaint_id}/status", response_model=ComplaintDetailResponse)
def update_complaint_status(
    complaint_id: int,
    status_in: ComplaintStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles([UserRole.OFFICER, UserRole.SUPERVISOR, UserRole.ADMIN])),
):
    """
    Update complaint status and optional officer assignment.
    Records transition in immutable status history log.
    Allowed for Officers, Supervisors, and Admins.
    """
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    # If officer is restricted to a department, verify department match
    if current_user.role == UserRole.OFFICER.value and current_user.department_id:
        if complaint.department_id != current_user.department_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Officers can only update complaints within their assigned department",
            )

    prev_status = complaint.status
    now = datetime.now(timezone.utc)

    # Apply updates
    complaint.status = status_in.status.value
    complaint.updated_at = now

    if status_in.assigned_officer_id is not None:
        # Verify assigned officer exists
        officer = db.query(User).filter(User.id == status_in.assigned_officer_id).first()
        if not officer:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Officer with ID {status_in.assigned_officer_id} not found",
            )
        complaint.assigned_officer_id = status_in.assigned_officer_id

    if status_in.status == ComplaintStatus.RESOLVED:
        complaint.resolved_at = now

    # Record history
    history = StatusHistory(
        complaint_id=complaint.id,
        previous_status=prev_status,
        new_status=status_in.status.value,
        changed_by_id=current_user.id,
        comments=status_in.comments or f"Status changed from {prev_status} to {status_in.status.value}",
        created_at=now,
    )
    db.add(history)
    db.commit()
    db.refresh(complaint)

    return complaint


@router.get("/{complaint_id}/timeline", response_model=List[StatusHistoryResponse])
def get_complaint_timeline(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve full chronological status timeline for a complaint."""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    if current_user.role == UserRole.CITIZEN.value and complaint.citizen_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this complaint's timeline",
        )

    return db.query(StatusHistory).filter(StatusHistory.complaint_id == complaint_id).order_by(StatusHistory.created_at.asc()).all()
