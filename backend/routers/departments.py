from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.deps import require_roles
from backend.models.department import Department
from backend.models.enums import UserRole
from backend.schemas.department import DepartmentCreate, DepartmentResponse

router = APIRouter(prefix="/departments", tags=["Departments"])


@router.get("", response_model=List[DepartmentResponse])
def list_departments(db: Session = Depends(get_db)):
    """List all municipal departments."""
    return db.query(Department).order_by(Department.name.asc()).all()


@router.post("", response_model=DepartmentResponse, status_code=status.HTTP_201_CREATED)
def create_department(
    dept_in: DepartmentCreate,
    db: Session = Depends(get_db),
    _admin_user=Depends(require_roles([UserRole.ADMIN])),
):
    """Create a new municipal department (Admin only)."""
    existing = db.query(Department).filter(Department.code == dept_in.code.upper()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Department with code '{dept_in.code.upper()}' already exists",
        )

    dept = Department(
        name=dept_in.name,
        code=dept_in.code.upper(),
        description=dept_in.description,
        contact_email=dept_in.contact_email,
        contact_phone=dept_in.contact_phone,
    )
    db.add(dept)
    db.commit()
    db.refresh(dept)
    return dept


@router.get("/{department_id}", response_model=DepartmentResponse)
def get_department(department_id: int, db: Session = Depends(get_db)):
    """Retrieve details for a specific department."""
    dept = db.query(Department).filter(Department.id == department_id).first()
    if not dept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Department not found",
        )
    return dept
