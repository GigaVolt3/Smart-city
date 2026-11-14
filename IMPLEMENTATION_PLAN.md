# Implementation Plan

Delivery plan for the CivicAI rebuild, with the state of each workstream at handover.
Phases are ordered by dependency: the API had to gain endpoints before either client
could be finished.

## Phase 0 — Baseline verification

| Step | Result |
| --- | --- |
| Clone and inspect repository | FastAPI + Flutter, four commits, no dashboard |
| Install Python deps (`email-validator`, `scikit-learn`, `numpy`, `pillow`, `httpx`) | Done |
| Run inherited test suite | 32 passed |
| Run `flutter pub get` / `flutter analyze` | Clean baseline |
| Identify dead mobile dependencies (`go_router`, `shimmer`, `uuid`) | Removed during rewrite |

## Phase 1 — Backend capability build-out

Deliverables, all implemented:

1. **Notifications** — `models/notification.py`, `schemas/notification.py`,
   `routers/notifications.py`, `services/notifications.py`.
   List with filters, unread count, mark-one, mark-all, delete. Every status change,
   assignment, new complaint, and escalation writes a notification.
2. **Analytics** — `schemas/analytics.py`, `routers/analytics.py`.
   Role-scoped overview: KPIs, status/priority mix, 30-day trend, departments,
   categories, wards, SLA summary, recent activity, map points, personal counters.
3. **Evidence uploads** — `services/uploads.py`, static `/uploads` mount, attachment
   create/list/delete on the complaint router. MIME and size validation, safe filenames.
4. **Profile management** — `PUT /auth/me`, `POST /auth/change-password`, audit writes.
5. **User administration** — officer directory, admin PATCH for role/department/active.
6. **Catalogue administration** — `PATCH /departments/{id}`, `PATCH /categories/{id}`.
7. **Escalation engine** — `services/escalation_engine.py` (rule selection, idempotent
   level advance, recipient resolution, notification fan-out, event recording),
   `routers/escalations.py` (summary, events, rules, run-sweep), lifespan worker.
8. **Audit trail** — `services/audit.py`, `routers/audit.py`, writes on complaint
   create/status/attachment, department/category edits, profile and password changes,
   escalation sweeps.
9. **Complaint query surface** — `/complaints/paged` with total, `overdue`,
   `assigned_to_me`, search, and all existing filters.
10. **Priority score correctness** — category default is a floor; `[Category Default]`
    factor emitted; LOW tier uses the category SLA instead of a hard 72h minimum.
11. **Seed data** — `backend/scripts/seed_demo.py` produces 5 departments,
    10 categories, 10 users, 48 complaints across 10 wards with timelines, escalation
    events, notifications, and a generated evidence image. Guarded against double runs.

## Phase 2 — Web operations console

| Workstream | Deliverable |
| --- | --- |
| Tooling | Vite 6 + React 19 + TypeScript, `tsc -b`, manual vendor chunks |
| Design system | `src/styles/globals.css`: tokens, layout primitives, 40+ component classes, breakpoints at 1240 / 1080 / 760 / 420, reduced-motion support |
| Data layer | `src/lib/api.ts` (typed fetch wrapper, token refresh), `src/lib/types.ts`, `src/hooks/queries.ts` (TanStack Query hooks with sensible stale times) |
| Auth | `AuthProvider` with persisted session, role guard, login/register pages, auto sign-out on 401 |
| Shell | Dark sidebar with grouped nav, collapsible rail, topbar search, notification menu, profile menu |
| Dashboard | KPI tiles, SLA posture, 30-day trend, status/priority mix, department table, "needs attention" queue |
| Complaints | Filterable table with pagination, saved URL state, status chips, bulk-free single-row actions |
| Complaint detail | Header with SLA countdown, AI panel, timeline, assignment/status update, evidence gallery, map snippet |
| New complaint | Full intake form with AI routing suggestion, category/department linkage, map point, first photo |
| Map | Leaflet/OSM, status-colored pins, ward/hotspot overlay, filter chips, side list synced to selection |
| Analytics | KPI row, trend, SLA compliance, department performance, category/ward breakdowns, hotspot list |
| Admin | Departments (create + edit), categories, users (create, role, activate), escalation rules + sweep, audit log |
| Notifications / Profile | Read state, mark-all, delete; profile edit, password change |
| Empty/error/loading | Skeleton blocks, empty states with guidance, toast notifications, 404 route |

Verification: `tsc -b` clean, `vite build` succeeds (index ~482 kB, charts chunk ~397 kB),
all routes exercised at 1440×900 and 390×844 against seeded data.

## Phase 3 — Mobile application

Rewritten as a real API client:

| Layer | Files |
| --- | --- |
| Models | `lib/data/models.dart` — user, complaint, detail, timeline, attachment, analytics, notification |
| Transport | `lib/data/api_client.dart` — token persistence, auto-refresh, multipart upload, typed errors, platform-aware base URL |
| State | `lib/core/providers.dart` — riverpod auth controller, complaint filters, analytics, notifications, shell tab |
| Theme | `lib/core/theme/app_theme.dart` — shared tokens and widget themes |
| Shell | `lib/features/shell/app_shell.dart` — bottom nav (Home / Cases / Map / Alerts / Profile), FAB for reporting |
| Screens | `auth`, `home`, `complaints` list + detail, `complaints/report`, `map`, `notifications`, `profile` |
| Shared widgets | `lib/core/widgets/civic_ui.dart` — section cards, status pills, KPI tiles, empty/error states, skeletons |

Removed: `demo_data.dart`, `go_router` setup, splash/onboarding, shimmer, uuid.
Verification: `flutter analyze` reports no issues, `flutter test` passes,
`flutter build web --release` succeeds, screens exercised at 390×844 against the live API.

## Phase 4 — QA and documentation

- Desktop QA across every route at 1440×900, mobile-width web at 390×844.
- Flutter web QA at 390×844: login, KPIs, case list and filters, detail and status
  update, report form with validation, map and hotspots, alerts, profile sign-out.
- Workflow QA: complaint creation → detail → status update → AI analysis; mark-all-read;
  profile save; department create; escalation sweep; admin/role guards.
- Defect fixes documented in CHANGELOG.md and QA_REPORT.md.
- Backend suite expanded from 32 to 50 tests covering every new endpoint.

## Risks and mitigations

| Risk | Mitigation | Outcome |
| --- | --- | --- |
| Dashboard scope larger than remaining time | Build the design system first, then pages reuse primitives | Delivered |
| Mobile rewrite breaking the "existing functionality" clause | Kept every original screen and flow, same roles, same data | Delivered |
| Timezone bugs from SQLite naive datetimes | `as_utc` on the server, `parseApiDate` on the client | One bug found and fixed |
| AI scoring producing absurd priorities | Floor at category default, unit-tested | Fixed |
| Fetching every complaint for analytics | Single aggregate endpoint with role scoping | Done |
| Scope creep into trained ML | Documented as a non-goal; heuristics stay explainable | Contained |

## What remains optional

- Playwright/Flutter integration suites.
- Kannada/Hindi localization.
- Production hardening items listed in PROJECT_ANALYSIS.md §6.
