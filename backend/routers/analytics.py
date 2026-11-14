from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session, joinedload

from backend.core.database import get_db
from backend.core.deps import get_current_user
from backend.models.complaint import Complaint
from backend.models.enums import (
    ComplaintPriority,
    ComplaintStatus,
    UserRole,
)
from backend.models.notification import Notification
from backend.models.status_history import StatusHistory
from backend.models.user import User
from backend.schemas.analytics import (
    ActivityItem,
    AnalyticsOverview,
    CategoryCount,
    DepartmentPerformance,
    KpiSummary,
    MapPoint,
    MyCounters,
    PriorityCount,
    SlaSummary,
    StatusCount,
    TrendPoint,
    WardCount,
)
from backend.services.escalation_engine import as_utc
from backend.services.scoping import apply_complaint_scope

router = APIRouter(prefix="/analytics", tags=["Analytics"])

RESOLVED_STATUSES = {ComplaintStatus.RESOLVED.value}
CLOSED_STATUSES = {
    ComplaintStatus.RESOLVED.value,
    ComplaintStatus.REJECTED.value,
}
STATUS_ORDER = [
    ComplaintStatus.SUBMITTED.value,
    ComplaintStatus.ASSIGNED.value,
    ComplaintStatus.IN_PROGRESS.value,
    ComplaintStatus.ESCALATED.value,
    ComplaintStatus.RESOLVED.value,
    ComplaintStatus.REJECTED.value,
]
PRIORITY_ORDER = [
    ComplaintPriority.CRITICAL.value,
    ComplaintPriority.HIGH.value,
    ComplaintPriority.MEDIUM.value,
    ComplaintPriority.LOW.value,
]


def _is_breached(complaint: Complaint, now: datetime) -> bool:
    if complaint.status in CLOSED_STATUSES:
        return False
    return as_utc(complaint.due_at) < now


def _resolution_hours(complaint: Complaint) -> Optional[float]:
    if not complaint.resolved_at:
        return None
    delta = as_utc(complaint.resolved_at) - as_utc(complaint.created_at)
    return round(max(0.0, delta.total_seconds() / 3600.0), 2)


def _pct(numerator: float, denominator: float) -> float:
    if not denominator:
        return 0.0
    return round((numerator / denominator) * 100.0, 1)


@router.get("/overview", response_model=AnalyticsOverview)
def analytics_overview(
    days: int = Query(30, ge=7, le=365, description="Trend window in days"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Role-scoped operational analytics for the dashboard and mobile home."""
    now = datetime.now(timezone.utc)
    window_start = now - timedelta(days=days)
    scoped = apply_complaint_scope(
        db.query(Complaint).options(
            joinedload(Complaint.department), joinedload(Complaint.category)
        ),
        current_user,
    )
    complaints = scoped.all()

    total = len(complaints)
    resolved = [c for c in complaints if c.status in RESOLVED_STATUSES]
    open_complaints = [c for c in complaints if c.status not in CLOSED_STATUSES]
    breached = [c for c in open_complaints if _is_breached(c, now)]
    critical_open = [
        c
        for c in open_complaints
        if c.priority == ComplaintPriority.CRITICAL.value
    ]

    resolution_hours = [
        value for value in (_resolution_hours(c) for c in resolved) if value is not None
    ]
    within_sla = [
        c
        for c in resolved
        if c.resolved_at and as_utc(c.resolved_at) <= as_utc(c.due_at)
    ]

    new_in_period = [c for c in complaints if as_utc(c.created_at) >= window_start]
    resolved_in_period = [
        c
        for c in resolved
        if c.resolved_at and as_utc(c.resolved_at) >= window_start
    ]

    status_counts = Counter(c.status for c in complaints)
    priority_counts = Counter(c.priority for c in complaints)

    # Daily trend (filled for every day so charts never have gaps)
    submitted_by_day = Counter(
        as_utc(c.created_at).date().isoformat() for c in complaints
    )
    resolved_by_day = Counter(
        as_utc(c.resolved_at).date().isoformat()
        for c in resolved
        if c.resolved_at
    )
    trend = []
    for offset in range(days - 1, -1, -1):
        day = (now - timedelta(days=offset)).date().isoformat()
        trend.append(
            TrendPoint(
                date=day,
                submitted=submitted_by_day.get(day, 0),
                resolved=resolved_by_day.get(day, 0),
            )
        )

    # Department performance
    dept_groups: dict[int, list[Complaint]] = defaultdict(list)
    dept_names: dict[int, tuple[str, str]] = {}
    for complaint in complaints:
        dept_groups[complaint.department_id].append(complaint)
        if complaint.department:
            dept_names[complaint.department_id] = (
                complaint.department.name,
                complaint.department.code,
            )

    departments = []
    for dept_id, rows in dept_groups.items():
        name, code = dept_names.get(dept_id, (f"Department {dept_id}", "—"))
        d_resolved = [c for c in rows if c.status in RESOLVED_STATUSES]
        d_open = [c for c in rows if c.status not in CLOSED_STATUSES]
        d_breached = [c for c in d_open if _is_breached(c, now)]
        d_within = [
            c
            for c in d_resolved
            if c.resolved_at and as_utc(c.resolved_at) <= as_utc(c.due_at)
        ]
        d_hours = [
            value
            for value in (_resolution_hours(c) for c in d_resolved)
            if value is not None
        ]
        departments.append(
            DepartmentPerformance(
                id=dept_id,
                name=name,
                code=code,
                total=len(rows),
                open=len(d_open),
                resolved=len(d_resolved),
                escalated=len(
                    [c for c in rows if c.status == ComplaintStatus.ESCALATED.value]
                ),
                breached=len(d_breached),
                sla_compliance_rate=_pct(len(d_within), len(d_resolved)),
                avg_resolution_hours=(
                    round(sum(d_hours) / len(d_hours), 1) if d_hours else 0.0
                ),
            )
        )
    departments.sort(key=lambda item: item.total, reverse=True)

    # Category breakdown
    category_counts: Counter[int] = Counter()
    category_meta: dict[int, tuple[str, Optional[str]]] = {}
    for complaint in complaints:
        category_counts[complaint.category_id] += 1
        if complaint.category:
            category_meta[complaint.category_id] = (
                complaint.category.name,
                complaint.department.name if complaint.department else None,
            )
    categories = sorted(
        [
            CategoryCount(
                id=cat_id,
                name=category_meta.get(cat_id, (f"Category {cat_id}", None))[0],
                department=category_meta.get(cat_id, ("", None))[1],
                count=count,
            )
            for cat_id, count in category_counts.items()
        ],
        key=lambda item: item.count,
        reverse=True,
    )

    # Ward hotspot table
    ward_groups: dict[str, list[Complaint]] = defaultdict(list)
    for complaint in complaints:
        ward_groups[complaint.ward].append(complaint)
    wards = sorted(
        [
            WardCount(
                ward=ward,
                total=len(rows),
                open=len([c for c in rows if c.status not in CLOSED_STATUSES]),
                breached=len(
                    [c for c in rows if c.status not in CLOSED_STATUSES and _is_breached(c, now)]
                ),
            )
            for ward, rows in ward_groups.items()
        ],
        key=lambda item: (item.breached, item.total),
        reverse=True,
    )

    # SLA summary for open work
    at_risk = [
        c
        for c in open_complaints
        if not _is_breached(c, now)
        and as_utc(c.due_at) <= now + timedelta(hours=24)
    ]
    sla = SlaSummary(
        on_track=len(open_complaints) - len(breached) - len(at_risk),
        at_risk=len(at_risk),
        breached=len(breached),
        compliance_rate=_pct(len(within_sla), len(resolved)),
    )

    # Recent activity feed (role-scoped)
    activity_rows = (
        db.query(StatusHistory)
        .join(Complaint, StatusHistory.complaint_id == Complaint.id)
        .options(
            joinedload(StatusHistory.changed_by),
            joinedload(StatusHistory.complaint),
        )
    )
    activity_rows = apply_complaint_scope(activity_rows, current_user)
    activity_rows = (
        activity_rows.order_by(StatusHistory.created_at.desc()).limit(10).all()
    )
    recent_activity = [
        ActivityItem(
            id=row.id,
            complaint_id=row.complaint_id,
            complaint_number=row.complaint.complaint_number if row.complaint else "",
            title=row.complaint.title if row.complaint else "",
            previous_status=row.previous_status,
            new_status=row.new_status,
            comments=row.comments,
            actor=row.changed_by.full_name if row.changed_by else "CivicAI Engine",
            created_at=row.created_at.isoformat(),
        )
        for row in activity_rows
    ]

    map_points = [
        MapPoint(
            id=c.id,
            complaint_number=c.complaint_number,
            title=c.title,
            status=c.status,
            priority=c.priority,
            latitude=c.latitude,
            longitude=c.longitude,
            ward=c.ward,
            category=c.category.name if c.category else "Uncategorised",
        )
        for c in complaints
        if c.latitude is not None and c.longitude is not None
    ][:300]

    my_assigned = 0
    my_filed = 0
    if current_user.role in (UserRole.OFFICER.value, UserRole.SUPERVISOR.value):
        my_assigned = len([c for c in complaints if c.assigned_officer_id == current_user.id])
    if current_user.role == UserRole.CITIZEN.value:
        my_filed = total
    if current_user.role in (UserRole.ADMIN.value, UserRole.SUPERVISOR.value):
        my_assigned = len([c for c in complaints if c.assigned_officer_id is not None])

    unread = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.is_read.is_(False),
        )
        .count()
    )

    return AnalyticsOverview(
        role=current_user.role,
        days=days,
        kpis=KpiSummary(
            total=total,
            open=len(open_complaints),
            resolved=len(resolved),
            rejected=len(
                [c for c in complaints if c.status == ComplaintStatus.REJECTED.value]
            ),
            escalated=len(
                [c for c in complaints if c.status == ComplaintStatus.ESCALATED.value]
            ),
            critical_open=len(critical_open),
            sla_breached=len(breached),
            new_in_period=len(new_in_period),
            resolved_in_period=len(resolved_in_period),
            resolution_rate=_pct(len(resolved), total),
            sla_compliance_rate=_pct(len(within_sla), len(resolved)),
            avg_resolution_hours=(
                round(sum(resolution_hours) / len(resolution_hours), 1)
                if resolution_hours
                else 0.0
            ),
        ),
        status_breakdown=[
            StatusCount(status=status, count=status_counts.get(status, 0))
            for status in STATUS_ORDER
        ],
        priority_breakdown=[
            PriorityCount(priority=priority, count=priority_counts.get(priority, 0))
            for priority in PRIORITY_ORDER
        ],
        trend=trend,
        departments=departments,
        categories=categories,
        wards=wards,
        sla=sla,
        recent_activity=recent_activity,
        map_points=map_points,
        my=MyCounters(
            assigned=my_assigned,
            filed=my_filed,
            unread_notifications=unread,
        ),
    )
