import math
from datetime import datetime, timedelta, timezone
from typing import Optional
from sqlalchemy.orm import Session

from backend.models.complaint import Complaint
from backend.models.category import ComplaintCategory
from backend.models.enums import ComplaintPriority, ComplaintStatus
from backend.models.status_history import StatusHistory
from backend.models.user import User

# Priority SLA Multipliers:
# Critical grievances get shorter turnaround times; low urgency grievances get extended buffers.
PRIORITY_SLA_MULTIPLIERS = {
    ComplaintPriority.CRITICAL.value: 0.5,
    ComplaintPriority.HIGH.value: 0.75,
    ComplaintPriority.MEDIUM.value: 1.0,
    ComplaintPriority.LOW.value: 1.5,
}


def get_priority_multiplier(priority: Optional[str]) -> float:
    """Return configured multiplier for priority, defaulting to 1.0 (medium)."""
    if not priority:
        return 1.0
    return PRIORITY_SLA_MULTIPLIERS.get(priority.lower(), 1.0)


def calculate_deadline(
    sla_hours: int,
    priority: Optional[str] = None,
    base_time: Optional[datetime] = None,
) -> datetime:
    """
    Calculate timezone-aware UTC due date based on category SLA hours and priority multiplier.
    Guarantees at least 1 hour minimum deadline.
    """
    if base_time is None:
        base_time = datetime.now(timezone.utc)
    elif base_time.tzinfo is None:
        base_time = base_time.replace(tzinfo=timezone.utc)

    multiplier = get_priority_multiplier(priority)
    effective_hours = max(1, math.ceil(sla_hours * multiplier))
    return base_time + timedelta(hours=effective_hours)


def calculate_category_deadline(
    category: ComplaintCategory,
    priority: Optional[str] = None,
    base_time: Optional[datetime] = None,
) -> datetime:
    """Convenience helper to compute deadline directly from category instance."""
    eff_priority = priority or category.priority_default
    return calculate_deadline(category.sla_hours, eff_priority, base_time)


def is_overdue(due_at: datetime, current_time: Optional[datetime] = None) -> bool:
    """Check whether a due date has expired."""
    if current_time is None:
        current_time = datetime.now(timezone.utc)
    elif current_time.tzinfo is None:
        current_time = current_time.replace(tzinfo=timezone.utc)

    if due_at.tzinfo is None:
        due_at = due_at.replace(tzinfo=timezone.utc)

    return current_time > due_at


def calculate_overdue_hours(due_at: datetime, current_time: Optional[datetime] = None) -> float:
    """Calculate the number of hours by which the deadline has passed."""
    if current_time is None:
        current_time = datetime.now(timezone.utc)
    elif current_time.tzinfo is None:
        current_time = current_time.replace(tzinfo=timezone.utc)

    if due_at.tzinfo is None:
        due_at = due_at.replace(tzinfo=timezone.utc)

    diff = (current_time - due_at).total_seconds() / 3600.0
    return max(0.0, round(diff, 2))


def extend_deadline(
    complaint: Complaint,
    additional_hours: int,
    reason: str,
    changed_by: User,
    db: Session,
) -> datetime:
    """
    Safely extend an existing complaint deadline.
    Records transition comment in status history timeline.
    """
    if additional_hours <= 0:
        raise ValueError("Extension duration must be greater than zero hours.")

    now = datetime.now(timezone.utc)
    old_due = complaint.due_at.replace(tzinfo=timezone.utc) if complaint.due_at.tzinfo is None else complaint.due_at
    # If already past due, extend from now; otherwise extend from existing due_at
    base = max(now, old_due)
    new_due = base + timedelta(hours=additional_hours)

    complaint.due_at = new_due
    complaint.updated_at = now

    history = StatusHistory(
        complaint_id=complaint.id,
        previous_status=complaint.status,
        new_status=complaint.status,
        changed_by_id=changed_by.id,
        comments=f"Deadline extended by {additional_hours}h. Reason: {reason}",
        created_at=now,
    )
    db.add(history)
    return new_due

