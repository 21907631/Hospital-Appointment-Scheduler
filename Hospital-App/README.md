# Hospital Appointment Scheduler

CMPE314 — Software Engineering — Group 03

A web-based platform for patients to book hospital appointments, doctors to manage their schedules, and admins to oversee the system.

```

- Frontend (React + Tailwind) — UI, talks to Supabase Auth directly for register/login, sends the access token to the Express API for everything else.
- Backend (Node.js + Express) — Validates Supabase JWTs, enforces role-based access (patient / doctor / admin), owns business logic (booking conflicts, reminders), proxies DB calls via supabase-js.
- Supabase (Postgres) — Database + Auth. Custom `profiles` table is linked to `auth.users` and stores the role.

## Project structure

```
backend/      Express API
frontend/     React app (Vite + Tailwind)
supabase/     SQL migrations (schema.sql)
docs/         API spec, UML diagrams, design notes
```

Backend:
   ```bash
   cd backend
   npm install
   npm run dev
   ```
Frontend:
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

## Milestones

| Milestone | Status | Scope |
|---|---|---|
| 1 — Auth & Profiles | ✅ Done | Supabase Auth, `profiles` table, role-based JWT middleware |
| 2 — Appointments & Doctors | 🚧 In progress | Doctor profiles, time slots, appointment booking & basic cancellation |
| 3 — Cancellation Window, Payments & Notifications | 🔮 Planned | See below |

### Milestone 3 — Planned Features

Driven by the Cancel Appointment activity diagram. Three things the current system is missing:

**1. 24-hour cancellation window enforcement**
- `schema_milestone3.sql` replaces the Milestone 2 patient-cancel RLS policy with one that calls `within_cancellation_window(appointment_id)`.
- The function checks `scheduled_at >= now() + interval '24 hours'`.
- Backend route `PATCH /api/appointments/:id/cancel` must also check this and return `403` if too late.

**2. Payments & Refund eligibility**
- New `payments` table — one row per booking, stores `amount` and `status` (`paid` / `refunded` / `pending`).
- New `refunds` table — created when a patient cancels a paid appointment within the window.
- Refund eligibility rule: appointment has a `payments` row with `status = 'paid'`.
- Backend logic: on cancellation, check for a payment row → if found, insert a `refunds` row and update `payments.status = 'refunded'`; otherwise just mark appointment `cancelled`.

**3. Notifications**
- New `notifications` table — one row per message per user (`type`, `title`, `body`, `read`, `metadata`).
- On successful cancellation the backend inserts:
  - A `cancellation_confirmed` notification for the patient.
  - A `doctor_notified` notification for the doctor.
  - A `refund_processed` notification for the patient (if refund was issued).
- Frontend polls `GET /api/notifications` (or uses Supabase Realtime) to show the notification bell.

**Migration order**
```
supabase/schema.sql              ← Milestone 1
supabase/schema_milestone2.sql   ← Milestone 2
supabase/schema_milestone3.sql   ← Milestone 3
```

## Team

| Member | Role |
|---|---|
| Sekou Boundy | Docs,System Design & Backend |
| Joseph Makolo Mupira | Backend & Testing |
| Misael Mirimo | Schema & Database |
| Seth Sunday Okpabi | Frontend (React) |
| Esperant Mungobo |  Notifications, Coordination |
