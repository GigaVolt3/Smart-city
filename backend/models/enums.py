from enum import Enum


class UserRole(str, Enum):
    CITIZEN = "citizen"
    OFFICER = "officer"
    SUPERVISOR = "supervisor"
    ADMIN = "admin"


class ComplaintStatus(str, Enum):
    SUBMITTED = "submitted"
    ASSIGNED = "assigned"
    IN_PROGRESS = "in_progress"
    ESCALATED = "escalated"
    RESOLVED = "resolved"
    REJECTED = "rejected"


class ComplaintPriority(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"
