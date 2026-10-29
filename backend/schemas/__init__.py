from backend.schemas.common import ErrorResponse, MessageResponse, PaginatedResponse
from backend.schemas.user import UserBase, UserRegister, UserCreateAdmin, UserUpdate, UserResponse
from backend.schemas.auth import LoginRequest, TokenResponse, RefreshTokenRequest, TokenPayload
from backend.schemas.department import DepartmentBase, DepartmentCreate, DepartmentUpdate, DepartmentResponse
from backend.schemas.category import CategoryBase, CategoryCreate, CategoryUpdate, CategoryResponse
from backend.schemas.complaint import (
    ComplaintCreate,
    ComplaintStatusUpdate,
    ComplaintResponse,
    ComplaintDetailResponse,
    AttachmentResponse,
    StatusHistoryResponse,
)

__all__ = [
    "ErrorResponse",
    "MessageResponse",
    "PaginatedResponse",
    "UserBase",
    "UserRegister",
    "UserCreateAdmin",
    "UserUpdate",
    "UserResponse",
    "LoginRequest",
    "TokenResponse",
    "RefreshTokenRequest",
    "TokenPayload",
    "DepartmentBase",
    "DepartmentCreate",
    "DepartmentUpdate",
    "DepartmentResponse",
    "CategoryBase",
    "CategoryCreate",
    "CategoryUpdate",
    "CategoryResponse",
    "ComplaintCreate",
    "ComplaintStatusUpdate",
    "ComplaintResponse",
    "ComplaintDetailResponse",
    "AttachmentResponse",
    "StatusHistoryResponse",
]
