import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.main import app
from backend.core.database import Base, get_db
from backend.core.security import hash_password, create_access_token
from backend.models.user import User
from backend.models.department import Department
from backend.models.category import ComplaintCategory
from backend.models.enums import UserRole

# Use in-memory SQLite for test isolation
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="session", autouse=True)
def setup_database():
    """Create all tables once for the test session."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session():
    """Provide a transactional database session rolled back after each test."""
    connection = engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(db_session):
    """FastAPI TestClient with overridden get_db dependency."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def seed_data(db_session):
    """Seed test department, category, and users for each role."""
    # Department
    dept = Department(
        name="Roads & Infrastructure",
        code="ROADS",
        description="Roads maintenance",
        contact_email="roads@test.civicai",
    )
    db_session.add(dept)
    db_session.flush()

    # Category
    cat = ComplaintCategory(
        department_id=dept.id,
        name="Pothole Repair",
        code="POTHOLE",
        description="Potholes on roads",
        sla_hours=48,
        priority_default="medium",
        is_active=True,
    )
    db_session.add(cat)
    db_session.flush()

    # Fictional users
    pwd_hash = hash_password("TestSecret123!")

    citizen = User(
        email="citizen@test.civicai",
        full_name="Citizen Tester",
        phone_number="9876543210",
        ward="Ward 12",
        role=UserRole.CITIZEN.value,
        hashed_password=pwd_hash,
        is_active=True,
    )
    other_citizen = User(
        email="other@test.civicai",
        full_name="Other Citizen",
        phone_number="9876543219",
        ward="Ward 15",
        role=UserRole.CITIZEN.value,
        hashed_password=pwd_hash,
        is_active=True,
    )
    officer = User(
        email="officer@test.civicai",
        full_name="Officer Tester",
        phone_number="9876543211",
        ward="Ward 12",
        department_id=dept.id,
        role=UserRole.OFFICER.value,
        hashed_password=pwd_hash,
        is_active=True,
    )
    supervisor = User(
        email="supervisor@test.civicai",
        full_name="Supervisor Tester",
        phone_number="9876543212",
        ward="East Zone",
        department_id=dept.id,
        role=UserRole.SUPERVISOR.value,
        hashed_password=pwd_hash,
        is_active=True,
    )
    admin = User(
        email="admin@test.civicai",
        full_name="Admin Tester",
        phone_number="9876543213",
        role=UserRole.ADMIN.value,
        hashed_password=pwd_hash,
        is_active=True,
    )

    db_session.add_all([citizen, other_citizen, officer, supervisor, admin])
    db_session.commit()

    return {
        "dept": dept,
        "category": cat,
        "citizen": citizen,
        "other_citizen": other_citizen,
        "officer": officer,
        "supervisor": supervisor,
        "admin": admin,
    }


def auth_header_for_user(user: User) -> dict:
    """Helper to generate Authorization header for a given user."""
    token = create_access_token({"sub": str(user.id), "email": user.email, "role": user.role})
    return {"Authorization": f"Bearer {token}"}
