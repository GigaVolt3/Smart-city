from backend.routers.auth import router as auth_router
from backend.routers.users import router as users_router
from backend.routers.departments import router as departments_router
from backend.routers.categories import router as categories_router
from backend.routers.complaints import router as complaints_router
from backend.routers.ai import router as ai_router
from backend.routers.analytics import router as analytics_router
from backend.routers.notifications import router as notifications_router
from backend.routers.escalations import router as escalations_router
from backend.routers.audit import router as audit_router

__all__ = [
    "auth_router",
    "users_router",
    "departments_router",
    "categories_router",
    "complaints_router",
    "ai_router",
    "analytics_router",
    "notifications_router",
    "escalations_router",
    "audit_router",
]
