from backend.routers.auth import router as auth_router
from backend.routers.users import router as users_router
from backend.routers.departments import router as departments_router
from backend.routers.categories import router as categories_router
from backend.routers.complaints import router as complaints_router
from backend.routers.escalation import router as escalation_router
from backend.routers.notifications import router as notifications_router

__all__ = [
    "auth_router",
    "users_router",
    "departments_router",
    "categories_router",
    "complaints_router",
    "escalation_router",
    "notifications_router",
]
