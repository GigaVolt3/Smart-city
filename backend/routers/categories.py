from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.deps import require_roles
from backend.models.category import ComplaintCategory
from backend.models.department import Department
from backend.models.enums import UserRole
from backend.schemas.category import CategoryCreate, CategoryResponse

router = APIRouter(prefix="/categories", tags=["Categories"])


@router.get("", response_model=List[CategoryResponse])
def list_categories(
    department_id: Optional[int] = Query(None, description="Filter categories by department ID"),
    is_active: Optional[bool] = Query(None, description="Filter by active status"),
    db: Session = Depends(get_db),
):
    """List complaint categories with optional department and active filter."""
    query = db.query(ComplaintCategory)
    if department_id is not None:
        query = query.filter(ComplaintCategory.department_id == department_id)
    if is_active is not None:
        query = query.filter(ComplaintCategory.is_active == is_active)
    return query.order_by(ComplaintCategory.name.asc()).all()


@router.post("", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
def create_category(
    cat_in: CategoryCreate,
    db: Session = Depends(get_db),
    _admin_user=Depends(require_roles([UserRole.ADMIN])),
):
    """Create a new complaint category (Admin only)."""
    dept = db.query(Department).filter(Department.id == cat_in.department_id).first()
    if not dept:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Department with ID {cat_in.department_id} does not exist",
        )

    existing = db.query(ComplaintCategory).filter(ComplaintCategory.code == cat_in.code.upper()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Category with code '{cat_in.code.upper()}' already exists",
        )

    category = ComplaintCategory(
        department_id=cat_in.department_id,
        name=cat_in.name,
        code=cat_in.code.upper(),
        description=cat_in.description,
        sla_hours=cat_in.sla_hours,
        priority_default=cat_in.priority_default.value,
        is_active=cat_in.is_active,
    )
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


@router.get("/{category_id}", response_model=CategoryResponse)
def get_category(category_id: int, db: Session = Depends(get_db)):
    """Retrieve details for a specific category."""
    category = db.query(ComplaintCategory).filter(ComplaintCategory.id == category_id).first()
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found",
        )
    return category
