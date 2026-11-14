from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.deps import require_roles
from backend.core.security import hash_password
from backend.models.department import Department
from backend.models.enums import UserRole
from backend.models.user import User
from backend.schemas.user import UserCreateAdmin, UserResponse, UserUpdate
from backend.services.audit import record_audit

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("", response_model=List[UserResponse])
def list_users(
    role: Optional[UserRole] = Query(None, description="Filter users by role"),
    department_id: Optional[int] = Query(None, description="Filter by department"),
    search: Optional[str] = Query(None, description="Search name or email"),
    is_active: Optional[bool] = Query(None),
    db: Session = Depends(get_db),
    _admin_user=Depends(require_roles([UserRole.ADMIN, UserRole.SUPERVISOR])),
):
    """List municipal users (Admin & Supervisor only)."""
    query = db.query(User)
    if role is not None:
        query = query.filter(User.role == role.value)
    if department_id is not None:
        query = query.filter(User.department_id == department_id)
    if is_active is not None:
        query = query.filter(User.is_active.is_(is_active))
    if search:
        term = f"%{search}%"
        query = query.filter(or_(User.full_name.ilike(term), User.email.ilike(term)))
    return query.order_by(User.full_name.asc()).all()


@router.post("", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user_by_admin(
    user_in: UserCreateAdmin,
    db: Session = Depends(get_db),
    admin_user=Depends(require_roles([UserRole.ADMIN])),
):
    """Create a new staff or municipal user account with designated role (Admin only)."""
    existing_user = db.query(User).filter(User.email == user_in.email.lower()).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email address already exists",
        )
    if user_in.department_id is not None:
        department = (
            db.query(Department).filter(Department.id == user_in.department_id).first()
        )
        if not department:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Department not found",
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
    record_audit(
        db,
        user=admin_user,
        action="user.created",
        resource_type="user",
        details=f"{user.email} role={user.role}",
    )
    db.commit()
    db.refresh(user)
    return user


@router.get("/officers", response_model=List[UserResponse])
def list_assignable_officers(
    department_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles([UserRole.OFFICER, UserRole.SUPERVISOR, UserRole.ADMIN])
    ),
):
    """Active officers/supervisors available for complaint assignment.

    Officers may only see colleagues in their own department.
    """
    query = db.query(User).filter(
        User.is_active.is_(True),
        User.role.in_([UserRole.OFFICER.value, UserRole.SUPERVISOR.value]),
    )
    if current_user.role == UserRole.OFFICER.value and current_user.department_id:
        query = query.filter(User.department_id == current_user.department_id)
    elif department_id is not None:
        query = query.filter(User.department_id == department_id)
    return query.order_by(User.full_name.asc()).all()


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


@router.patch("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: int,
    user_in: UserUpdate,
    db: Session = Depends(get_db),
    admin_user=Depends(require_roles([UserRole.ADMIN])),
):
    """Update a user's role, department, profile, or activation state (Admin only)."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    updates = user_in.model_dump(exclude_unset=True)

    if updates.get("role") is not None:
        role = updates["role"]
        updates["role"] = role.value if hasattr(role, "value") else role
    if "department_id" in updates and updates["department_id"] is not None:
        if not db.query(Department).filter(Department.id == updates["department_id"]).first():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="Department not found"
            )
    if updates.get("is_active") is False and user.id == admin_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot deactivate your own account",
        )

    for field, value in updates.items():
        setattr(user, field, value)

    record_audit(
        db,
        user=admin_user,
        action="user.updated",
        resource_type="user",
        resource_id=user.id,
        details=", ".join(f"{key}={value}" for key, value in updates.items()),
    )
    db.commit()
    db.refresh(user)
    return user
