# CivicAI — FastAPI Backend Service

This is the backend service for **CivicAI — AI-Powered Smart Civic Grievance and Escalation System**. Built with FastAPI, SQLAlchemy 2.0, PostgreSQL (with SQLite fallback for ₹0 zero-setup local dev), and Alembic.

---

## 🚀 Features Implemented (Phase 2)

- **Authentication & Authorization**:
  - JWT Access Token (HS256, 60m expiry) + Refresh Token (7d expiry)
  - Bcrypt password hashing (cost factor 12)
  - Role-Based Access Control (RBAC) supporting:
    - `citizen`
    - `officer`
    - `supervisor`
    - `admin`
- **Data Models & Schema**:
  - `User`, `Department`, `ComplaintCategory`, `Complaint`, `ComplaintAttachment`, `StatusHistory`, `EscalationRule`, `EscalationEvent`, `AuditEvent`
  - Automated Alembic migrations tracking schema evolution
  - Foreign key constraints, indexes on lookup fields, cascade policies
- **Complaint Management Lifecycle**:
  - Auto-generated sequential tracking numbers (`CIVIC-YYYY-XXXX`)
  - SLA due date calculation dynamically derived from category configuration
  - Immutable status history timeline logging each transition, actor, and comment
  - Scoped data access: citizens see only their own complaints, officers see department cases, admins/supervisors have oversight
- **Development Seed Data**:
  - 5 Indian municipal departments (`ROADS`, `SAN`, `ELEC`, `WATER`, `DRAIN`)
  - 10 realistic complaint categories with realistic SLA deadlines
  - 4 fictional demo accounts with pre-populated roles
  - Realistic multi-stage complaints with status history

---

## 🛠️ Quick Start

### 1. Environment Setup

```powershell
cd backend

# Create virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

### 2. Configure Environment

Copy `.env.example` to `.env` (pre-configured for instant SQLite local development):

```powershell
Copy-Item .env.example .env
```

For PostgreSQL:
```env
DATABASE_URL=postgresql+psycopg://civicai:civicai@localhost:5432/civicai_db
```

### 3. Run Migrations & Seed Demo Data

```powershell
$env:PYTHONPATH="d:\Projects\Smart City\Smart-city"

# Apply Alembic schema migrations
alembic upgrade head

# Seed demo accounts and complaints
python -m backend.scripts.seed_demo
```

### 4. Start Development Server

```powershell
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

- **Interactive API Docs (Swagger UI)**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **Alternative API Docs (ReDoc)**: [http://localhost:8000/redoc](http://localhost:8000/redoc)
- **Health Check**: [http://localhost:8000/health](http://localhost:8000/health)

---

## 👥 Demo Accounts (Fictional Dev Credentials)

| Role | Email | Password | Scope |
|---|---|---|---|
| **Citizen** | `citizen@demo.civicai` | `DemoPass1!` | View & submit own grievances |
| **Officer** | `officer@demo.civicai` | `DemoPass1!` | Ward Assistant Engineer (Roads) |
| **Supervisor** | `supervisor@demo.civicai` | `DemoPass1!` | Executive Engineer (East Zone) |
| **Admin** | `admin@demo.civicai` | `DemoPass1!` | Municipal Commissioner / Admin |

---

## 🧪 Automated Tests

Run the full pytest suite (17 unit & integration tests covering auth, RBAC, CRUD, SLA calculation, and timeline):

```powershell
$env:PYTHONPATH="d:\Projects\Smart City\Smart-city"
pytest -v
```
