-- =====================================================
-- Hospital Appointment Scheduler — Milestone 2 Schema
-- Run this AFTER schema.sql in the Supabase SQL Editor
-- =====================================================

-- ─── 1. Specializations ───────────────────────────────────────────────────────
create table public.specializations (
  id          serial primary key,
  name        text not null unique,  -- e.g. 'Cardiology', 'Pediatrics'
  created_at  timestamptz not null default now()
);

insert into public.specializations (name) values
  ('General Practice'),
  ('Cardiology'),
  ('Dermatology'),
  ('Neurology'),
  ('Orthopedics'),
  ('Pediatrics'),
  ('Psychiatry'),
  ('Radiology');

-- ─── 2. Doctors ───────────────────────────────────────────────────────────────
-- Each doctor row links to a profile (role = 'doctor') and adds medical info.
create table public.doctors (
  id                  uuid primary key references public.profiles(id) on delete cascade,
  specialization_id   int  not null references public.specializations(id),
  bio                 text,
  consultation_fee    numeric(10,2) not null default 0,
  available           boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create trigger doctors_updated_at
  before update on public.doctors
  for each row execute function public.set_updated_at();

-- ─── 3. Time Slots ────────────────────────────────────────────────────────────
-- Recurring weekly availability windows a doctor sets up.
-- day_of_week: 0 = Sunday … 6 = Saturday (ISO: 1 = Monday … 7 = Sunday)
create table public.time_slots (
  id           serial primary key,
  doctor_id    uuid not null references public.doctors(id) on delete cascade,
  day_of_week  smallint not null check (day_of_week between 0 and 6),
  start_time   time not null,
  end_time     time not null,
  slot_minutes int  not null default 30,    -- appointment duration in minutes
  created_at   timestamptz not null default now(),
  constraint time_slots_order check (end_time > start_time)
);

-- ─── 4. Appointment Status enum ───────────────────────────────────────────────
create type appointment_status as enum ('pending', 'confirmed', 'cancelled', 'completed');

-- ─── 5. Appointments ──────────────────────────────────────────────────────────
create table public.appointments (
  id             uuid primary key default gen_random_uuid(),
  patient_id     uuid not null references public.profiles(id) on delete cascade,
  doctor_id      uuid not null references public.doctors(id)  on delete cascade,
  scheduled_at   timestamptz not null,          -- exact start date+time
  duration_min   int not null default 30,
  status         appointment_status not null default 'pending',
  reason         text,                          -- patient's stated reason
  notes          text,                          -- doctor's internal notes
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  -- prevent double-booking the same doctor at the same time
  constraint appointments_no_double_book unique (doctor_id, scheduled_at)
);

create trigger appointments_updated_at
  before update on public.appointments
  for each row execute function public.set_updated_at();

-- Index: patient looking up their own appointments
create index on public.appointments (patient_id, scheduled_at desc);
-- Index: doctor looking up their schedule
create index on public.appointments (doctor_id, scheduled_at);

-- ─── 6. Row Level Security ────────────────────────────────────────────────────

-- specializations: anyone can read
alter table public.specializations enable row level security;
create policy "Anyone can view specializations"
  on public.specializations for select using (true);

-- doctors: anyone can read; only the doctor themselves or admins can update
alter table public.doctors enable row level security;

create policy "Anyone can view doctors"
  on public.doctors for select using (true);

create policy "Doctor can update own record"
  on public.doctors for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Admin can update any doctor"
  on public.doctors for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- time_slots: anyone can read; only the owning doctor or admin can write
alter table public.time_slots enable row level security;

create policy "Anyone can view time_slots"
  on public.time_slots for select using (true);

create policy "Doctor manages own time_slots"
  on public.time_slots for all
  using (auth.uid() = doctor_id)
  with check (auth.uid() = doctor_id);

create policy "Admin manages all time_slots"
  on public.time_slots for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- appointments: patient sees their own; doctor sees theirs; admin sees all
alter table public.appointments enable row level security;

create policy "Patient views own appointments"
  on public.appointments for select
  using (auth.uid() = patient_id);

create policy "Doctor views own schedule"
  on public.appointments for select
  using (auth.uid() = doctor_id);

create policy "Admin views all appointments"
  on public.appointments for select
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Patient can create appointment"
  on public.appointments for insert
  with check (auth.uid() = patient_id);

create policy "Patient can cancel own appointment"
  on public.appointments for update
  using (auth.uid() = patient_id)
  with check (status = 'cancelled');

create policy "Doctor can update appointment notes/status"
  on public.appointments for update
  using (auth.uid() = doctor_id);

create policy "Admin can do anything with appointments"
  on public.appointments for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );
