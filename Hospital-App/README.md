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

## Team

| Member | Role |
|---|---|
| Sekou Boundy | Docs,System Design & Backend |
| Joseph Makolo Mupira | Backend & Testing |
| Misael Mirimo | Schema & Database |
| Seth Sunday Okpabi | Frontend (React) |
| Esperant Mungobo |  Notifications, Coordination |
