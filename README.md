# CivicAI — AI-Powered Smart Civic Grievance and Escalation System

> **Final-Year Engineering Project** | Indian Municipality Smart Governance Platform

CivicAI is a mobile-first civic complaint management system designed for Indian municipalities. Citizens can report civic issues (potholes, garbage, broken streetlights, water leakage, etc.) and the system uses AI to classify, deduplicate, prioritize and automatically escalate unresolved complaints through a configurable authority chain.

---

## Monorepo Structure

```
civicai/
├── mobile/          # Flutter Android application (Dart)
├── backend/         # Python FastAPI REST API + AI services
├── dashboard/       # React authority dashboard (Phase 7)
└── docs/            # Architecture, schema, API docs, setup guides
```

## Quick Start

See individual component READMEs:
- [Mobile (Flutter)](mobile/README.md)
- [Backend (FastAPI)](backend/README.md)
- [Dashboard (React)](dashboard/README.md)
- [Documentation](docs/README.md)

## Tech Stack

| Layer       | Technology                                      |
|-------------|-------------------------------------------------|
| Mobile      | Flutter 3.44+, Dart 3.12+, Riverpod, GoRouter  |
| Backend     | Python 3.14, FastAPI, SQLAlchemy, APScheduler  |
| Database    | PostgreSQL 15 + PostGIS (SQLite fallback)       |
| AI / ML     | scikit-learn, sentence-transformers, OpenCV     |
| Dashboard   | React 19, Vite, TanStack Query                 |
| Auth        | JWT (python-jose), bcrypt                       |

## Budget

This project targets **₹0 cost**. All technologies are free and open-source. The application runs fully locally during development and demonstration.

## Development Phases

| Phase | Description                                   | Status    |
|-------|-----------------------------------------------|-----------|
| 1     | Flutter foundation + navigation + demo UI     | ✅ Complete |
| 2     | FastAPI backend + PostgreSQL schema + seeds   | ✅ Complete |
| 3     | Flutter ↔ Backend integration + auth          | 🔲 Next   |
| 4     | Escalation engine + scheduler + audit         | 🔲         |
| 5     | AI classification + duplicate detection       | 🔲         |
| 6     | Evidence upload + resolution verification     | 🔲         |
| 7     | React authority dashboard                     | 🔲         |
| 8     | Predictive maintenance + Kannada locale       | 🔲         |
| 9     | Testing, docs, clean-env verification         | 🔲         |

## License

MIT — for academic demonstration purposes only. Not for production municipal deployment.
