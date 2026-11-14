# Project Analysis

Audit of the inherited CivicAI codebase, gap analysis against the delivery brief, and
the decisions taken before implementation.

## 1. Baseline inventory

The repository contained four commits and three deployable artefacts.

| Area | What existed | State at handover |
| --- | --- | --- |
| Backend | FastAPI app, SQLAlchemy 2 models, Alembic migrations, JWT auth, RBAC, complaint lifecycle, seed script, 32 pytest cases | Working. Installed deps, all 32 tests green. |
| Mobile | Flutter app with splash, onboarding, login/register, home, complaint list, detail, submit form, notifications, profile | UI only. Every screen rendered `demo_data.dart`; no HTTP client, no auth token handling, dead router/shimmer/uuid dependencies. |
| Dashboard | `dashboard/` referenced in README and project phases | **Did not exist.** No React app, no design system, no authority console. |
| AI | `backend/ai/` with classifier, priority scorer, duplicate detector, hotspot clustering, image verification | Present and importable, but priority scoring could downgrade a category's configured default, and the complaint create path pointed at a stale module path. |
| Docs | `docs/architecture.md`, `docs/setup.md`, phase table in README | Described phases 1-2 only; phases 3-9 listed as not started. |

## 2. Requirement gaps

The brief asked for a production-quality desktop console **and** a real mobile client,
sharing data, auth, and backend. Mapping that onto the baseline produced these gaps.

### 2.1 Missing backend capability

| Capability | Needed by | Baseline |
| --- | --- | --- |
| Notification persistence | Bell menu, mobile alerts tab | Model and endpoints absent |
| Analytics aggregation | Dashboards, charts, KPIs | No aggregation endpoint at all |
| Evidence upload storage | Complaint detail gallery, mobile camera | `ComplaintAttachment` model existed, no upload endpoint, no static mount |
| Profile and password management | Profile page (both clients) | Read-only `/auth/me` |
| Assignable officer directory | Assignment picker | Users list restricted to admin, no officer endpoint |
| Department / category editing | Admin screens | Create + read only |
| Escalation engine + sweep endpoint | Escalation page, worker | Rules and events models existed; no engine, no scheduler |
| Audit trail API | Audit page | Audit model existed with no read endpoint and almost no writes |
| Paged complaint feed with total | Table pagination | Flat list with `skip`/`limit` but no total |
| SLA / assignment filters | "Needs attention" queue | No `overdue` or `assigned_to_me` filters |

These were built rather than stubbed. Nothing in the UI reads fabricated data.

### 2.2 Missing client capability

- No React application whatsoever. Every screen in the brief (dashboard, complaints,
  detail, map, analytics, departments, users, notifications, profile, escalations,
  audit, auth, 404) had to be authored.
- Mobile had no networking layer. `pubspec.yaml` had `go_router`, `shimmer`, `uuid`,
  and a demo dataset instead of `http`. Rewritten as a real API client.
- No shared visual language. Only a partial Material theme existed in `mobile/`.

## 3. Decisions

| Decision | Rationale | Alternatives rejected |
| --- | --- | --- |
| Keep FastAPI, extend in place | 32 passing tests, working auth and lifecycle, correct domain model | Rewrite in Node/Nest, which would discard the only tested layer |
| Add `dashboard/` as a separate React 19 + Vite + TS SPA | Brief requires a desktop console; SPA keeps deploy simple and reuses the REST API | Server-rendered Next.js (no SSR requirement), Electron (unnecessary weight) |
| One design system expressed twice (CSS custom properties and Dart constants) | Web and mobile must look related without sharing a build pipeline | Component library (e.g. MUI) which would fight the civic visual direction |
| Responsive web **and** dedicated Flutter app | Brief asks for both; mobile stays a real client, not a viewport trick | PWA only (loses camera/native feel), Flutter-only (weak desktop ergonomics) |
| TanStack Query for server state | Caching, invalidation, and retry semantics for free; no global store needed | Redux (boilerplate), Zustand + manual fetch (reinvents caching) |
| Recharts, Leaflet + OpenStreetMap | Open, free, no API key, matches the ₹0 constraint | Mapbox/Google Maps (keys, billing), Chart.js (weaker React ergonomics) |
| SQLite by default, PostgreSQL-ready | Zero-setup demo, SQLAlchemy models already portable | Mandatory Postgres (blocked grading machines) |
| Realistic seeded data (48 complaints) instead of an empty app | Analytics, maps, and escalation need volume to be meaningful | Empty state only, or hand-written fixtures in the client |
| Priority = max(category default, computed score) | A pothole must not be scored below a category's configured floor | Pure model score (produced nonsensical downgrades) |
| Local disk uploads behind `/uploads` | No S3 dependency for a demo | Cloud storage (credentials, cost) |

## 4. Architectural observations

- **Authorization is centralized** in `services/scoping.py` and applied to list,
  analytics, escalation, and export queries, so role leaks are fixed in one place.
- **Timeline entries are immutable**; status changes append `StatusHistory` rows and never
  mutate history. Escalation is idempotent per `(complaint, to_level)`.
- **SLA math is timezone-explicit.** SQLite returns naive datetimes, so the API normalizes
  with `as_utc` and clients append `Z` before formatting. This was the source of one
  visible bug during QA (negative "time remaining"), now handled in `parseApiDate`.
- **Analytics are computed per request** from indexed tables. Acceptable at demo scale
  (48 rows), documented as a materialized-view candidate for production.

## 5. Deliberate non-goals

- Trained ML models. The classifier and scorer are deterministic heuristics; the brief
  forbids fake data, so the UI labels AI output as suggestions the officer can override.
- Multi-tenant municipality isolation, i18n beyond English, push notifications, offline
  write queue, and file virus scanning. Each is listed in the production gap list below.

## 6. Production gap list

| Gap | Impact | Suggested next step |
| --- | --- | --- |
| SQLite single file, no migrations applied for new tables | No concurrent write scale | Point `DATABASE_URL` at PostgreSQL and generate Alembic revisions for notifications/attachments |
| Local disk uploads | Not durable across instances | S3-compatible bucket with signed URLs |
| In-process APScheduler worker | Duplicate sweeps if scaled horizontally | Dedicated worker + advisory lock |
| Analytics computed on read | Slower as rows grow | Nightly rollup tables or materialized views |
| Heuristic AI | Misclassification on unseen categories | Train on historical resolved complaints; keep human override |
| No rate limiting or account lockout | Brute-force exposure | Reverse-proxy limits, exponential backoff on login |
| English-only copy | Accessibility for local users | Kannada/Hindi locale files (Flutter intl already wired) |
| No automated E2E suite | Regressions caught manually | Playwright for web, integration_test for Flutter |
