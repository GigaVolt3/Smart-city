# CivicAI — Architecture Documentation

## Overview

CivicAI is a monorepo comprising three main components:

```
Smart-city/
├── mobile/       # Flutter Android app (citizen-facing)
├── backend/      # Python FastAPI REST API + AI engine
├── dashboard/    # React authority/officer dashboard
└── docs/         # This documentation
```

## Folder Structure: Feature-First

### Mobile (`mobile/lib/`)

```
lib/
├── main.dart                          # App entry point
├── core/
│   ├── theme/app_theme.dart           # Design system (colors, typography, spacing)
│   ├── router/app_router.dart         # GoRouter configuration + shell route
│   ├── constants/                     # App-wide string/int constants
│   ├── utils/                         # Formatters, validators, helpers
│   ├── widgets/                       # Shared UI components
│   ├── network/                       # Dio client, interceptors (Phase 3)
│   └── services/                      # Storage, location, notifications (Phase 3)
└── features/
    ├── splash/                        # Splash screen
    ├── onboarding/                    # First-run onboarding
    ├── auth/
    │   ├── presentation/screens/      # login_screen, register_screen
    │   ├── data/                      # Auth API, token storage (Phase 3)
    │   └── domain/                    # Auth entities, providers (Phase 3)
    ├── home/
    │   └── presentation/screens/      # home_screen (stats + quick actions)
    ├── complaints/
    │   ├── presentation/screens/      # submit, list, detail screens
    │   ├── data/models/               # Complaint models + demo_data.dart
    │   └── domain/                    # Riverpod providers (Phase 3)
    ├── notifications/
    │   └── presentation/screens/
    └── profile/
        └── presentation/screens/
```

### Backend (`backend/`) — Phase 2

```
backend/
├── main.py                # FastAPI app entry
├── core/
│   ├── config.py          # Settings from environment variables
│   ├── database.py        # SQLAlchemy engine + session
│   └── security.py        # JWT, bcrypt helpers
├── models/                # SQLAlchemy ORM models
├── schemas/               # Pydantic request/response schemas
├── routers/               # FastAPI route handlers (one per domain)
├── services/              # Business logic (escalation engine, AI, etc.)
├── workers/               # APScheduler escalation worker
├── migrations/            # Alembic migration scripts
├── tests/                 # pytest unit + integration tests
├── requirements.txt
└── .env.example
```

## Database Schema (Phase 2)

### Core tables

| Table               | Purpose                                    |
|---------------------|--------------------------------------------|
| `users`             | Citizens, officers, supervisors, admins    |
| `departments`       | Municipal departments                      |
| `complaint_categories` | Configurable category taxonomy          |
| `complaints`        | Core complaint record                      |
| `complaint_attachments` | Photos/videos per complaint            |
| `status_history`    | Immutable status transition log            |
| `assignments`       | Complaint-to-officer assignment history    |
| `escalation_rules`  | Per-department / per-category rules        |
| `escalation_events` | Immutable escalation audit log             |
| `officer_notes`     | Internal notes per complaint               |
| `resolution_evidence` | Before/after photo pairs               |
| `citizen_feedback`  | Post-resolution satisfaction + disputes    |
| `notifications`     | Notification queue + delivery status       |
| `audit_events`      | Admin action audit trail                   |

## API Endpoints (Phase 2)

### Auth
- `POST /auth/register` — register citizen
- `POST /auth/login` — obtain JWT
- `POST /auth/refresh` — refresh token
- `POST /auth/logout` — invalidate token

### Complaints
- `GET  /complaints` — list own complaints (citizen) or all (officer+)
- `POST /complaints` — submit new complaint
- `GET  /complaints/{id}` — detail view
- `PUT  /complaints/{id}/status` — update status (officer+)
- `GET  /complaints/{id}/timeline` — full status + escalation history
- `POST /complaints/{id}/evidence` — upload resolution evidence
- `POST /complaints/{id}/feedback` — citizen resolution feedback

### Escalation
- `GET  /escalation/rules` — list escalation rules (admin)
- `POST /escalation/rules` — create rule (admin)
- `GET  /complaints/{id}/escalations` — escalation history

### Admin
- `GET/POST /departments` — manage departments
- `GET/POST /categories` — manage complaint categories

## Escalation Engine Design (Phase 4)

The escalation engine runs as an `APScheduler` background job:

```
Every N minutes:
1. SELECT complaints WHERE status NOT IN (resolved, closed, rejected)
       AND due_at < NOW()
       AND NOT already escalated at this level
       FOR UPDATE SKIP LOCKED  ← prevents duplicate escalation on concurrent runs
2. For each eligible complaint:
   a. Look up next escalation authority from escalation_rules
   b. Wrap in a transaction:
      - Insert escalation_event (immutable)
      - Insert status_history entry
      - Update complaint.escalation_level
      - Insert notification for citizen + new authority
      - Commit
3. Log result
```

**Idempotency guarantee**: The `FOR UPDATE SKIP LOCKED` + transaction + `escalation_events` deduplication ensure a complaint is never escalated twice for the same deadline breach, even if the scheduler overlaps.

## AI Modules (Phase 5)

| Module                  | Technique                          | Fallback                |
|-------------------------|------------------------------------|-------------------------|
| Classification          | Zero-shot via sentence-transformers | Keyword-based rules     |
| Duplicate detection     | Sentence embedding cosine similarity + geo radius | Text overlap only |
| Priority scoring        | Weighted rule formula (explained)  | Severity + age only     |
| Resolution verification | OpenCV image comparison (SSIM)     | Manual review flag      |
| Predictive maintenance  | Cluster analysis on resolved cases | Hotspot frequency table |

All AI outputs include a `confidence` field and a human-readable `explanation`. Scores below a threshold trigger mandatory human review.

## Security Controls

| Control                  | Implementation                             |
|--------------------------|--------------------------------------------|
| Authentication           | JWT (HS256), 30 min access + 7 day refresh |
| Password storage         | bcrypt (cost 12)                           |
| Authorization            | Role enum enforced in FastAPI dependencies |
| Input validation         | Pydantic on all request bodies             |
| File validation          | MIME type + size check before storage      |
| Secrets management       | `python-dotenv` — never in source control  |
| Audit trail              | `audit_events` table, insert-only          |
| Rate limiting            | `slowapi` (Phase 3)                        |

## Demo Accounts (Phase 2 seed data)

| Role          | Email                       | Password    |
|---------------|-----------------------------|-------------|
| Citizen       | citizen@demo.civicai        | DemoPass1!  |
| Officer       | officer@demo.civicai        | DemoPass1!  |
| Supervisor    | supervisor@demo.civicai     | DemoPass1!  |
| Admin         | admin@demo.civicai          | DemoPass1!  |

> **Note**: These are fictional accounts for local demonstration only.  
> Never represent these as real municipal accounts.
