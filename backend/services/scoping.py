"""Role-based visibility rules for complaint queries.

Kept in one place so every read path (list, analytics, escalations, exports)
applies the same authorization boundary.
"""

from sqlalchemy import or_
from sqlalchemy.orm import Query

from backend.models.complaint import Complaint
from backend.models.enums import UserRole
from backend.models.user import User


def apply_complaint_scope(query: Query, user: User) -> Query:
    """Restrict a Complaint query to the records the caller may see."""
    role = user.role

    if role == UserRole.CITIZEN.value:
        return query.filter(Complaint.citizen_id == user.id)

    if role == UserRole.OFFICER.value:
        conditions = [Complaint.assigned_officer_id == user.id]
        if user.department_id:
            conditions.append(Complaint.department_id == user.department_id)
        return query.filter(or_(*conditions))

    # Supervisors and admins see the whole municipal dataset.
    return query
