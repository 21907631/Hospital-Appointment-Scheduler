-- =====================================================
-- Hospital Appointment Scheduler — Initial Schema
-- Run this in the Supabase SQL Editor (Project → SQL Editor → New query)
-- =====================================================

-- 1. Role enum
create type user_role as enum ('patient', 'doctor', 'admin');

-- 2. Profiles table — extends auth.users with app-specific fields
-- auth.users is managed by Supabase Auth; we link to it 1:1 via the same UUID.
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null unique,
  full_name   text,
  role        user_role not null default 'patient',
  phone       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- 3. Trigger to auto-create a profile row when a new auth user signs up.
-- The role is read from the user's `raw_user_meta_data` (set during signUp).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'patient')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. Updated_at trigger
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- 5. Row Level Security
-- Even though the backend uses the service_role key (which bypasses RLS),
-- we enable RLS so any direct frontend reads stay safe.
alter table public.profiles enable row level security;

-- Users can read their own profile
create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

-- Users can update their own profile (but not change their role)
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id and role = (select role from public.profiles where id = auth.uid()));

-- Admins can read everyone (used for the admin dashboard)
create policy "Admins can view all profiles"
  on public.profiles for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );
