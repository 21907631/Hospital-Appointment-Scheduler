-- =====================================================
-- Hospital Appointment Scheduler — Milestone 3 Schema
-- Run this AFTER schema_milestone2.sql in the Supabase SQL Editor
-- Adds: cancellation window enforcement, payments, refunds, notifications
-- =====================================================

-- ─── 1. Payments ──────────────────────────────────────────────────────────────
-- Tracks payment made by the patient when booking an appointment.
create table public.payments (
  id              uuid primary key default gen_random_uuid(),
  appointment_id  uuid not null references public.appointments(id) on delete cascade,
  patient_id      uuid not null references public.profiles(id),
  amount          numeric(10,2) not null,
  status          text not null default 'paid'
                    check (status in ('paid', 'refunded', 'pending')),
  paid_at         timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger payments_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

create index on public.payments (appointment_id);
create index on public.payments (patient_id);

-- ─── 2. Refunds ───────────────────────────────────────────────────────────────
-- Created when a cancelled appointment had a payment and is refund-eligible.
create table public.refunds (
  id              uuid primary key default gen_random_uuid(),
  payment_id      uuid not null references public.payments(id) on delete cascade,
  appointment_id  uuid not null references public.appointments(id),
  patient_id      uuid not null references public.profiles(id),
  amount          numeric(10,2) not null,
  status          text not null default 'pending'
                    check (status in ('pending', 'processed', 'denied')),
  reason          text,
  processed_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger refunds_updated_at
  before update on public.refunds
  for each row execute function public.set_updated_at();

create index on public.refunds (appointment_id);
create index on public.refunds (patient_id);

-- ─── 3. Notifications ─────────────────────────────────────────────────────────
-- In-app notification log. Each row is one message to one user.
-- type values: 'cancellation_confirmed' | 'refund_processed' | 'appointment_reminder'
--              | 'doctor_notified' | 'booking_confirmed'
create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  type        text not null,
  title       text not null,
  body        text not null,
  read        boolean not null default false,
  metadata    jsonb,           -- e.g. { appointment_id, refund_id }
  created_at  timestamptz not null default now()
);

create index on public.notifications (user_id, created_at desc);

-- ─── 4. Cancellation Window Function ──────────────────────────────────────────
-- Returns true when the appointment is still >= 24 hours away (can cancel).
create or replace function public.within_cancellation_window(appointment_id uuid)
returns boolean
language sql stable security definer as $$
  select scheduled_at >= now() + interval '24 hours'
  from public.appointments
  where id = appointment_id;
$$;

-- ─── 5. Replace patient cancel RLS policy to enforce 24h window ───────────────
-- Drop the old policy from milestone 2 and replace it with one that checks
-- the cancellation window via the function above.
drop policy if exists "Patient can cancel own appointment" on public.appointments;

create policy "Patient can cancel own appointment within window"
  on public.appointments for update
  using (
    auth.uid() = patient_id
    and public.within_cancellation_window(id)
  )
  with check (status = 'cancelled');

-- ─── 6. Row Level Security for new tables ─────────────────────────────────────

-- payments
alter table public.payments enable row level security;

create policy "Patient views own payments"
  on public.payments for select
  using (auth.uid() = patient_id);

create policy "Admin manages all payments"
  on public.payments for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- refunds
alter table public.refunds enable row level security;

create policy "Patient views own refunds"
  on public.refunds for select
  using (auth.uid() = patient_id);

create policy "Admin manages all refunds"
  on public.refunds for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- notifications
alter table public.notifications enable row level security;

create policy "User views own notifications"
  on public.notifications for select
  using (auth.uid() = user_id);

create policy "User marks own notifications read"
  on public.notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Admin manages all notifications"
  on public.notifications for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );
