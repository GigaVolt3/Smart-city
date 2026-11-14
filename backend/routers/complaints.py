from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from sqlalchemy import desc, or_
from sqlalchemy.orm import Session, joinedload

from backend.ai.priority_scorer import CivicPriorityScorer
from backend.core.config import settings
from backend.core.database import get_db
from backend.core.deps import get_current_user, require_roles
from backend.models.category import ComplaintCategory
from backend.models.complaint import Complaint, ComplaintAttachment
from backend.models.department import Department
from backend.models.enums import ComplaintPriority, ComplaintStatus, UserRole
from backend.models.escalation import EscalationEvent
from backend.models.status_history import StatusHistory
from backend.models.user import User
from backend.schemas.complaint import (
    AttachmentResponse,
    ComplaintCreate,
    ComplaintDetailResponse,
    ComplaintPage,
    ComplaintResponse,
    ComplaintStatusUpdate,
    StatusHistoryResponse,
)
from backend.services.audit import record_audit
from backend.services.notifications import notify_users
from backend.services.scoping import apply_complaint_scope
from backend.services.uploads import disk_path_for_public_path, save_upload

router = APIRouter(prefix="/complaints", tags=["Complaints"])

priority_scorer = CivicPriorityScorer()

MANAGER_ROLES = {UserRole.OFFICER.value, UserRole.SUPERVISOR.value, UserRole.ADMIN.value}


def _db_now() -> datetime:
    """Naive UTC for SQLite comparisons; aware UTC everywhere else."""
    now = datetime.now(timezone.utc)
    if settings.DATABASE_URL.startswith("sqlite"):
        return now.replace(tzinfo=None)
    return now


def _generate_complaint_number(db: Session) -> str:
    """Generate sequential unique complaint reference number: CIVIC-YYYY-XXXX."""
    current_year = datetime.now(timezone.utc).year
    prefix = f"CIVIC-{current_year}-"
    count = db.query(Complaint).filter(Complaint.complaint_number.like(f"{prefix}%")).count()
    return f"{prefix}{count + 1:04d}"


def _load_complaint(db: Session, complaint_id: int) -> Complaint:
    complaint = (
        db.query(Complaint)
        .options(
            joinedload(Complaint.citizen),
            joinedload(Complaint.assigned_officer),
            joinedload(Complaint.department),
            joinedload(Complaint.category),
            joinedload(Complaint.attachments),
            joinedload(Complaint.status_history),
            joinedload(Complaint.escalation_events),
        )
        .filter(Complaint.id == complaint_id)
        .first()
    )
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found"
        )
    return complaint


def _assert_can_view(complaint: Complaint, user: User) -> None:
    if user.role == UserRole.CITIZEN.value and complaint.citizen_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this complaint",
        )
    if user.role == UserRole.OFFICER.value and user.department_id:
        if (
            complaint.department_id != user.department_id
            and complaint.assigned_officer_id != user.id
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="This complaint belongs to another department",
            )


def _assert_can_manage(complaint: Complaint, user: User) -> None:
    if user.role in (UserRole.ADMIN.value, UserRole.SUPERVISOR.value):
        return
    if user.role == UserRole.OFFICER.value:
        if user.department_id and complaint.department_id != user.department_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Officers can only manage complaints in their department",
            )
        return
    if user.role == UserRole.CITIZEN.value and complaint.citizen_id == user.id:
        return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="You do not have permission to modify this complaint",
    )


def _filtered_query(
    db: Session,
    current_user: User,
    *,
    status_filter: Optional[ComplaintStatus],
    department_id: Optional[int],
    category_id: Optional[int],
    priority: Optional[ComplaintPriority],
    ward: Optional[str],
    search: Optional[str],
    assigned_to_me: bool,
    overdue: bool,
):
    query = apply_complaint_scope(db.query(Complaint), current_user)

    if status_filter is not None:
        query = query.filter(Complaint.status == status_filter.value)
    if department_id is not None:
        query = query.filter(Complaint.department_id == department_id)
    if category_id is not None:
        query = query.filter(Complaint.category_id == category_id)
    if priority is not None:
        query = query.filter(Complaint.priority == priority.value)
    if ward:
        query = query.filter(Complaint.ward.ilike(f"%{ward}%"))
    if search:
        term = f"%{search}%"
        query = query.filter(
            or_(
                Complaint.title.ilike(term),
                Complaint.description.ilike(term),
                Complaint.complaint_number.ilike(term),
                Complaint.address.ilike(term),
            )
        )
    if assigned_to_me:
        query = query.filter(Complaint.assigned_officer_id == current_user.id)
    if overdue:
        query = query.filter(
            Complaint.due_at < _db_now(),
            Complaint.status.notin_(
                [ComplaintStatus.RESOLVED.value, ComplaintStatus.REJECTED.value]
            ),
        )
    return query


@router.post("", response_model=ComplaintResponse, status_code=status.HTTP_201_CREATED)
def create_complaint(
    complaint_in: ComplaintCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Submit a new civic complaint.
    Auto-assigns a unique complaint number, computes SLA due_at, records the initial
    status history, notifies the responsible department, and uses AI priority scoring
    when the citizen does not set a priority explicitly.
    """
    dept = db.query(Department).filter(Department.id == complaint_in.department_id).first()
    if not dept:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Department with ID {complaint_in.department_id} not found",
        )

    category = (
        db.query(ComplaintCategory)
        .filter(
            ComplaintCategory.id == complaint_in.category_id,
            ComplaintCategory.department_id == complaint_in.department_id,
        )
        .first()
    )
    if not category:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Category not found or does not belong to the selected department",
        )

    priority_order = {
        ComplaintPriority.LOW.value: 1,
        ComplaintPriority.MEDIUM.value: 2,
        ComplaintPriority.HIGH.value: 3,
        ComplaintPriority.CRITICAL.value: 4,
    }

    if complaint_in.priority:
        priority = complaint_in.priority.value
        initial_comments = "Grievance submitted by citizen"
        sla_hours = category.sla_hours
    else:
        ai_eval = priority_scorer.score_complaint(
            title=complaint_in.title,
            description=complaint_in.description,
            category_id=category.id,
            ward=complaint_in.ward,
            address=complaint_in.address,
            landmark=complaint_in.landmark,
            db=db,
        )
        ai_prio = ai_eval["priority_level"]
        cat_prio = category.priority_default
        if priority_order.get(ai_prio, 2) >= priority_order.get(cat_prio, 2):
            priority = ai_prio
            sla_hours = ai_eval["recommended_sla_hours"]
            primary_factor = (
                ai_eval["factors"][0] if ai_eval["factors"] else "AI evaluated priority"
            )
            initial_comments = (
                f"Grievance submitted (AI Priority: {ai_prio.upper()} - {primary_factor})"
            )
        else:
            priority = cat_prio
            sla_hours = category.sla_hours
            initial_comments = "Grievance submitted by citizen"

    now = datetime.now(timezone.utc)
    due_at = now + timedelta(hours=sla_hours)
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
    db.flush()

    db.add(
        StatusHistory(
            complaint_id=complaint.id,
            previous_status=None,
            new_status=ComplaintStatus.SUBMITTED.value,
            changed_by_id=current_user.id,
            comments=initial_comments,
            created_at=now,
        )
    )

    # Alert the department's staff; fall back to municipal admins.
    staff = (
        db.query(User)
        .filter(
            User.department_id == dept.id,
            User.role.in_([UserRole.OFFICER.value, UserRole.SUPERVISOR.value]),
            User.is_active.is_(True),
        )
        .all()
    )
    if not staff:
        staff = (
            db.query(User)
            .filter(User.role == UserRole.ADMIN.value, User.is_active.is_(True))
            .all()
        )
    notify_users(
        db,
        [user.id for user in staff],
        title="New complaint in your department",
        message=(
            f"{complaint.complaint_number} — {complaint.title} was submitted in "
            f"{complaint.ward} and is due {due_at.strftime('%d %b, %H:%M UTC')}."
        ),
        notification_type="new_complaint",
        complaint_id=complaint.id,
    )

    record_audit(
        db,
        user=current_user,
        action="complaint.created",
        resource_type="complaint",
        resource_id=complaint.id,
        details=f"{complaint.complaint_number} priority={priority}",
    )

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
    search: Optional[str] = Query(None, description="Search title, description, number, address"),
    assigned_to_me: bool = Query(False, description="Only complaints assigned to caller"),
    overdue: bool = Query(False, description="Only SLA-breached open complaints"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List complaints visible to the caller (role-scoped) with filters."""
    query = _filtered_query(
        db,
        current_user,
        status_filter=status,
        department_id=department_id,
        category_id=category_id,
        priority=priority,
        ward=ward,
        search=search,
        assigned_to_me=assigned_to_me,
        overdue=overdue,
    )
    return query.order_by(desc(Complaint.created_at)).offset(skip).limit(limit).all()


@router.get("/paged", response_model=ComplaintPage)
def list_complaints_paged(
    status: Optional[ComplaintStatus] = Query(None),
    department_id: Optional[int] = Query(None),
    category_id: Optional[int] = Query(None),
    priority: Optional[ComplaintPriority] = Query(None),
    ward: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    assigned_to_me: bool = Query(False),
    overdue: bool = Query(False),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Paginated complaint table feed with a total count."""
    query = _filtered_query(
        db,
        current_user,
        status_filter=status,
        department_id=department_id,
        category_id=category_id,
        priority=priority,
        ward=ward,
        search=search,
        assigned_to_me=assigned_to_me,
        overdue=overdue,
    )
    total = query.count()
    items = (
        query.order_by(desc(Complaint.created_at)).offset(skip).limit(limit).all()
    )
    return ComplaintPage(items=items, total=total, skip=skip, limit=limit)


@router.get("/{complaint_id}", response_model=ComplaintDetailResponse)
def get_complaint(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Full complaint record with citizen, officer, department, timeline and evidence."""
    complaint = _load_complaint(db, complaint_id)
    _assert_can_view(complaint, current_user)
    return complaint


@router.put("/{complaint_id}/status", response_model=ComplaintDetailResponse)
def update_complaint_status(
    complaint_id: int,
    status_in: ComplaintStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles([UserRole.OFFICER, UserRole.SUPERVISOR, UserRole.ADMIN])
    ),
):
    """
    Update complaint status and optional officer assignment.
    Records an immutable timeline entry and notifies the citizen and assignee.
    """
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found"
        )

    if current_user.role == UserRole.OFFICER.value and current_user.department_id:
        if complaint.department_id != current_user.department_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Officers can only update complaints within their assigned department",
            )

    previous_status = complaint.status
    previous_officer_id = complaint.assigned_officer_id
    now = datetime.now(timezone.utc)

    complaint.status = status_in.status.value
    complaint.updated_at = now

    if status_in.assigned_officer_id is not None:
        officer = (
            db.query(User)
            .filter(
                User.id == status_in.assigned_officer_id,
                User.role.in_(
                    [UserRole.OFFICER.value, UserRole.SUPERVISOR.value]
                ),
                User.is_active.is_(True),
            )
            .first()
        )
        if not officer:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Active officer with ID {status_in.assigned_officer_id} not found",
            )
        complaint.assigned_officer_id = status_in.assigned_officer_id

    if status_in.status == ComplaintStatus.RESOLVED:
        complaint.resolved_at = now
    elif previous_status == ComplaintStatus.RESOLVED.value:
        # Re-opened complaint: clear the stale resolution timestamp.
        complaint.resolved_at = None

    db.add(
        StatusHistory(
            complaint_id=complaint.id,
            previous_status=previous_status,
            new_status=status_in.status.value,
            changed_by_id=current_user.id,
            comments=status_in.comments
            or f"Status changed from {previous_status} to {status_in.status.value}",
            created_at=now,
        )
    )

    recipient_ids = [complaint.citizen_id]
    if complaint.assigned_officer_id:
        recipient_ids.append(complaint.assigned_officer_id)
    if current_user.id:
        recipient_ids = [uid for uid in recipient_ids if uid != current_user.id]

    if status_in.status == ComplaintStatus.RESOLVED:
        title = "Your complaint was resolved"
        message = (
            f"{complaint.complaint_number} — {complaint.title} has been marked resolved."
        )
    else:
        title = "Complaint status updated"
        message = (
            f"{complaint.complaint_number} moved from {previous_status} to "
            f"{status_in.status.value}."
        )

    notify_users(
        db,
        recipient_ids,
        title=title,
        message=message,
        notification_type="status_change",
        complaint_id=complaint.id,
    )

    if (
        complaint.assigned_officer_id
        and complaint.assigned_officer_id != previous_officer_id
    ):
        notify_users(
            db,
            [complaint.assigned_officer_id],
            title="Complaint assigned to you",
            message=(
                f"{complaint.complaint_number} — {complaint.title} in {complaint.ward} "
                f"is due {complaint.due_at.strftime('%d %b, %H:%M')}."
            ),
            notification_type="assignment",
            complaint_id=complaint.id,
        )

    record_audit(
        db,
        user=current_user,
        action="complaint.status_updated",
        resource_type="complaint",
        resource_id=complaint.id,
        details=f"{previous_status} -> {status_in.status.value}",
    )

    db.commit()
    db.refresh(complaint)
    return _load_complaint(db, complaint.id)


@router.get("/{complaint_id}/timeline", response_model=List[StatusHistoryResponse])
def get_complaint_timeline(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve the full chronological status timeline for a complaint."""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found"
        )
    _assert_can_view(complaint, current_user)
    return (
        db.query(StatusHistory)
        .filter(StatusHistory.complaint_id == complaint_id)
        .order_by(StatusHistory.created_at.asc())
        .all()
    )


@router.post(
    "/{complaint_id}/attachments",
    response_model=AttachmentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_attachment(
    complaint_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Attach photo/document evidence to a complaint (max size configurable)."""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found"
        )
    _assert_can_manage(complaint, current_user)

    public_path, size, mime_type = await save_upload(file, complaint.id)
    attachment = ComplaintAttachment(
        complaint_id=complaint.id,
        file_path=public_path,
        file_name=file.filename or "evidence",
        file_size=size,
        mime_type=mime_type,
    )
    db.add(attachment)
    complaint.updated_at = datetime.now(timezone.utc)
    record_audit(
        db,
        user=current_user,
        action="complaint.attachment_added",
        resource_type="complaint",
        resource_id=complaint.id,
        details=attachment.file_name,
    )
    db.commit()
    db.refresh(attachment)
    return attachment


@router.get("/{complaint_id}/attachments", response_model=List[AttachmentResponse])
def list_attachments(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    complaint = _load_complaint(db, complaint_id)
    _assert_can_view(complaint, current_user)
    return complaint.attachments


@router.delete(
    "/{complaint_id}/attachments/{attachment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_attachment(
    complaint_id: int,
    attachment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found"
        )
    _assert_can_manage(complaint, current_user)

    attachment = (
        db.query(ComplaintAttachment)
        .filter(
            ComplaintAttachment.id == attachment_id,
            ComplaintAttachment.complaint_id == complaint_id,
        )
        .first()
    )
    if not attachment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Attachment not found"
        )

    try:
        disk_path_for_public_path(attachment.file_path).unlink(missing_ok=True)
    except OSError:
        pass

    record_audit(
        db,
        user=current_user,
        action="complaint.attachment_deleted",
        resource_type="complaint",
        resource_id=complaint.id,
        details=attachment.file_name,
    )
    db.delete(attachment)
    db.commit()
    return None
