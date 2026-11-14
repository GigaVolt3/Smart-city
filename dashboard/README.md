# CivicAI Operations Console

Desktop-first staff console for the CivicAI municipal grievance platform. React 19,
Vite 6, TypeScript, TanStack Query, Recharts, Leaflet.

## Run

```bash
npm install
npm run dev        # http://127.0.0.1:5173
```

The dev server proxies `/api` and `/uploads` to `http://127.0.0.1:8000`, so no env file
is required. To point at another backend, set `VITE_BACKEND_URL` in `dashboard/.env`:

```
VITE_BACKEND_URL=http://127.0.0.1:8000
```

For a static deployment, set `VITE_API_URL` to the absolute API base
(`https://host/api/v1`) and `VITE_ASSET_ORIGIN` to the host that serves `/uploads`.

## Build

```bash
npm run build      # tsc -b && vite build  -> dist/
npm run preview
npm run lint       # type check only
```

Build output is split into vendor chunks (react, query, charts, maps) so the map and
chart bundles load only on the routes that need them.

## Sign in

Use a seeded account with password `DemoPass1!`:

| Email | Sees |
| --- | --- |
| `citizen@demo.civicai` | Own complaints, own analytics |
| `officer@demo.civicai` | Department complaints, assignment, status updates |
| `supervisor@demo.civicai` | Department oversight, escalation sweeps |
| `admin@demo.civicai` | Everything, including people, catalogue, audit |

The login screen also has one-click demo profile chips that fill the form.

## Routes

| Path | Page | Access |
| --- | --- | --- |
| `/` | Overview | All roles |
| `/complaints` | Complaint queue | All roles (scoped) |
| `/complaints/new` | Report an issue | All roles |
| `/complaints/:id` | Complaint detail | Scoped |
| `/map` | Live complaint map | All roles |
| `/analytics` | Municipal analytics | All roles (scoped) |
| `/escalations` | Escalation control | Supervisor, admin |
| `/departments` | Departments and categories | All roles; edits admin |
| `/users` | People and roles | Supervisor, admin |
| `/audit` | Audit trail | Admin |
| `/notifications` | Notifications | All roles |
| `/profile` | Profile and settings | All roles |
| `/login`, `/register` | Auth | Public |

## Structure

```
src/
  App.tsx                  routing, guards, providers
  pages/                   one file per route
  components/
    layout/                shell, sidebar, topbar, mobile nav, page header
    dashboard/             KPI, SLA ring, attention list, trend
    complaints/            status badges, timeline, AI panel, evidence
    maps/                  leaflet canvas, pins, hotspots, popup
    charts/                recharts wrappers
    ui/                    button, card, modal, toast, empty state, skeleton
  hooks/queries.ts         TanStack Query hooks
  lib/api.ts               typed fetch client with token refresh
  lib/types.ts             API response types
  providers/               auth session, toast queue
  styles/globals.css       design system + responsive rules
```

## Conventions

- Server state lives in TanStack Query only; no duplicated global store.
- Every mutation invalidates the queries it affects and surfaces a toast.
- Filters and pagination live in the URL.
- Loading uses layout-matched skeletons; errors use the same card shells.
- All colors, radii, and shadows come from CSS variables in `globals.css`. Do not
  hard-code hex values in components.

See [../DESIGN_SYSTEM.md](../DESIGN_SYSTEM.md) for tokens and component rules.
