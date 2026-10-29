from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.security import hash_password
from backend.core.deps import require_roles
from backend.models.user import User
from backend.models.enums import UserRole
from backend.schemas.user import UserCreateAdmin, UserResponse, UserUpdate

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("", response_model=List[UserResponse])
def list_users(
    role: Optional[UserRole] = Query(None, description="Filter users by role"),
    department_id: Optional[int] = Query(None, description="Filter by department"),
    db: Session = Depends(get_db),
    _admin_user=Depends(require_roles([UserRole.ADMIN, UserRole.SUPERVISOR])),
):
    """List users filtered by role or department (Admin & Supervisor only)."""
    query = db.query(User)
    if role is not None:
        query = query.filter(User.role == role.value)
    if department_id is not None:
        query = query.filter(User.department_id == department_id)
    return query.order_by(User.full_name.asc()).all()


@router.post("", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user_by_admin(
    user_in: UserCreateAdmin,
    db: Session = Depends(get_db),
    _admin_user=Depends(require_roles([UserRole.ADMIN])),
):
    """Create a new staff or municipal user account with designated role (Admin only)."""
    existing_user = db.query(User).filter(User.email == user_in.email.lower()).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email address already exists",
        )

    user = User(
        email=user_in.email.lower(),
        full_name=user_in.full_name,
        phone_number=user_in.phone_number,
        ward=user_in.ward,
        role=user_in.role.value,
        department_id=user_in.department_id,
        hashed_password=hash_password(user_in.password),
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("/{user_id}", response_model=UserResponse)
def get_user_by_id(
    user_id: int,
    db: Session = Depends(get_db),
    _admin_user=Depends(require_roles([UserRole.ADMIN, UserRole.SUPERVISOR])),
):
    """Get user by ID (Admin & Supervisor only)."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user
