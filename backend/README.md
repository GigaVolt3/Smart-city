# CivicAI — FastAPI Backend Service

This is the backend service for **CivicAI — AI-Powered Smart Civic Grievance and Escalation System**. Built with FastAPI, SQLAlchemy 2.0, PostgreSQL (with SQLite fallback for ₹0 zero-setup local dev), and Alembic.

---

## 🚀 Features Implemented

### Phase 2: Core Platform
- **Authentication & Authorization**:
  - JWT Access Token (HS256, 60m expiry) + Refresh Token (7d expiry)
  - Bcrypt password hashing (cost factor 12)
  - Role-Based Access Control (RBAC) supporting `citizen`, `officer`, `supervisor`, `admin`
- **Data Models & Schema**:
  - `User`, `Department`, `ComplaintCategory`, `Complaint`, `ComplaintAttachment`, `StatusHistory`, `AuditEvent`
- **Complaint Management**:
  - Auto-generated sequential tracking numbers (`CIVIC-YYYY-XXXX`)
  - Scoped data access: citizens view own grievances; officers view department cases; admins/supervisors have full oversight

### Phase 4: Automatic Escalation Engine (Member 3)
- **Configurable SLA Deadline Management**:
  - Dynamic deadline calculation based on category SLA hours and priority multipliers (Critical: 0.5x, High: 0.75x, Medium: 1.0x, Low: 1.5x)
  - Timezone-aware UTC calculations
  - Authorized deadline extension with status history tracking (`POST /api/v1/complaints/{id}/extend-deadline`)
- **Automatic Overdue Complaint Checker**:
  - Background task powered by `APScheduler` (checks every `ESCALATION_CHECK_INTERVAL_SECONDS`, default 60s)
  - Row-level database locking with fallback for SQLite
  - Automatically identifies overdue unresolved grievances, skipping resolved and rejected cases
- **Multi-Level Municipal Authority Escalation**:
  - Level 1: Assigned Ward Officer (`officer`)
  - Level 2: Department Supervisor (`supervisor`)
  - Level 3: Municipal Commissioner / Head Administrator (`admin`)
  - Configurable hierarchy via database rules (`escalation_rules`) with category, department, and global fallbacks
  - Support for manual escalation by authorized officers and supervisors
- **Idempotency & Duplicate Escalation Prevention**:
  - Database-level unique constraint on `(complaint_id, to_level)` in `escalation_events` table
  - Transaction-safe atomic transitions with automatic rollback on error
- **In-App Notification Queue**:
  - Automatic alerts dispatched to newly responsible authorities and grievance owners upon escalation
  - Dedicated notification management APIs (`GET /api/v1/notifications`, `PATCH /api/v1/notifications/{id}/read`, `POST /api/v1/notifications/mark-all-read`)
- **Escalation Audit Trail**:
  - Permanent immutable records storing `from_level`, `to_level`, `reason`, `trigger_type`, `escalated_from_id`, `escalated_to_id`, `deadline_exceeded_hours`, `created_at`
  - Supervisor acknowledgement endpoint (`POST /api/v1/escalation/{event_id}/acknowledge`)
  - Protected API to retrieve complaint escalation history (`GET /api/v1/complaints/{id}/escalations`)

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

Run the full pytest suite (36 unit & integration tests covering auth, RBAC, CRUD, SLA calculation, multi-level escalation, duplicate prevention, background scheduler, and the 15-step demonstration scenario):

```powershell
$env:PYTHONPATH="."
.\backend\.venv\Scripts\pytest.exe -v
```

---

## 🎬 15-Step End-to-End Live Demonstration

To execute the guided municipal grievance escalation demonstration for your guide or external examiner:

```powershell
$env:PYTHONPATH="."
.\backend\.venv\Scripts\python.exe -m backend.scripts.demo_escalation
```

This runs through the complete 15-step cycle:
1. Pothole complaint created by citizen
2. Assigned to Ward Assistant Engineer (Officer)
3. Simulated SLA deadline configured
4. Deadline expiration verified
5. Background overdue checker triggered
6. Automatic escalation to Supervisor (Level 2)
7. In-app alert verified in supervisor's notification inbox
8. Escalation event confirmed in database
9. Second SLA expiration simulated
10. Automatic escalation to Chief Municipal Administrator (Level 3)
11. Secondary escalation event logged in audit trail
12. Scheduler re-executed
13. Duplicate escalation prevention verified (idempotency guarantee)
14. Grievance marked as RESOLVED by authority
15. Resolved grievance verified as permanently excluded from further escalations

---

## 📡 API Reference (Escalation & Notifications)

| Method | Endpoint | Allowed Roles | Description |
|---|---|---|---|
| `GET` | `/api/v1/escalation/rules` | Admin | List all active/inactive municipal escalation rules |
| `POST` | `/api/v1/escalation/rules` | Admin | Create new escalation rule threshold |
| `PUT` | `/api/v1/escalation/rules/{id}` | Admin | Update rule hours or target role |
| `DELETE` | `/api/v1/escalation/rules/{id}` | Admin | Remove escalation rule |
| `POST` | `/api/v1/escalation/trigger-check` | Admin | Manually trigger overdue complaint checker |
| `GET` | `/api/v1/escalation/worker-status` | Admin | Check APScheduler background worker operational metrics |
| `GET` | `/api/v1/escalation/assigned` | Officer, Supervisor, Admin | View escalated grievances currently assigned to caller |
| `POST` | `/api/v1/escalation/{id}/acknowledge` | Officer, Supervisor, Admin | Acknowledge active handling of escalated grievance |
| `POST` | `/api/v1/complaints/{id}/escalate` | Officer, Supervisor, Admin | Manually escalate a grievance |
| `POST` | `/api/v1/complaints/{id}/extend-deadline`| Supervisor, Admin | Extend complaint SLA deadline with audit comment |
| `GET` | `/api/v1/complaints/{id}/escalations` | Citizen Owner, Staff | View chronological escalation events for complaint |
| `GET` | `/api/v1/notifications` | Any Authenticated | List user's in-app notifications |
| `GET` | `/api/v1/notifications/unread-count` | Any Authenticated | Retrieve unread alert count |
| `PATCH` | `/api/v1/notifications/{id}/read` | Any Authenticated | Mark notification as read |
| `POST` | `/api/v1/notifications/mark-all-read` | Any Authenticated | Mark all notifications as read |
