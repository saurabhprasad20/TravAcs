-- ============================================================================
-- TravAcs — 0001 init: enums, tables, indexes
-- Mirrors design_travacs.md §5. v1 stores NO Aadhaar data (manual verification).
-- ============================================================================

-- Needed for gen_random_uuid() and crypt()/gen_salt() (trip OTP hashing).
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Enums (§5.1)
-- ---------------------------------------------------------------------------
create type user_role           as enum ('requester', 'volunteer', 'admin');
create type gender_type         as enum ('male', 'female', 'other', 'prefer_not_to_say');
create type verification_status as enum ('pending', 'approved', 'rejected');
create type request_status      as enum ('draft', 'broadcast', 'assigned', 'started', 'completed', 'closed', 'cancelled');
create type payment_status      as enum ('pending', 'awaiting_other', 'confirmed');
create type rater_role          as enum ('requester', 'volunteer');

-- ---------------------------------------------------------------------------
-- profiles — one row per auth user (PK = auth.users.id)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  role          user_role   not null,
  full_name     text        not null,
  gender        gender_type,
  date_of_birth date,
  phone         text,
  is_active     boolean     not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- requester_profiles — 1:1 with a requester profile
-- ---------------------------------------------------------------------------
create table public.requester_profiles (
  profile_id         uuid primary key references public.profiles (id) on delete cascade,
  home_location_text text,
  home_lat           double precision,
  home_lng           double precision,
  rating_avg         numeric(2, 1) not null default 0.0,
  rating_count       int           not null default 0,
  created_at         timestamptz   not null default now(),
  updated_at         timestamptz   not null default now()
);

-- ---------------------------------------------------------------------------
-- volunteer_profiles — 1:1 with a volunteer profile. NO Aadhaar columns in v1.
-- ---------------------------------------------------------------------------
create table public.volunteer_profiles (
  profile_id          uuid primary key references public.profiles (id) on delete cascade,
  address             text,
  verification_status verification_status not null default 'pending',
  verified_by         uuid references public.profiles (id),
  verified_at         timestamptz,
  rejection_reason    text,
  rating_avg          numeric(2, 1) not null default 0.0,
  rating_count        int           not null default 0,
  created_at          timestamptz   not null default now(),
  updated_at          timestamptz   not null default now()
);

-- ---------------------------------------------------------------------------
-- requests — the core entity (§5.2)
-- ---------------------------------------------------------------------------
create table public.requests (
  id                        uuid primary key default gen_random_uuid(),
  requester_id              uuid not null references public.profiles (id) on delete cascade,
  volunteer_id              uuid references public.profiles (id),
  status                    request_status not null default 'broadcast',
  scheduled_date            date not null,
  start_time                time not null,
  expected_duration_minutes int  not null check (expected_duration_minutes > 0),
  pickup_text               text not null,
  pickup_lat                double precision,
  pickup_lng                double precision,
  destination_text          text not null,
  dest_lat                  double precision,
  dest_lng                  double precision,
  requirements              text,
  instructions              text,
  otp_hash                  text,            -- set on assignment; bcrypt hash
  service_area              text,            -- geo-ready filter (unused v1)
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

create index requests_status_idx        on public.requests (status);
create index requests_requester_idx     on public.requests (requester_id);
create index requests_volunteer_idx     on public.requests (volunteer_id);
create index requests_scheduled_idx     on public.requests (scheduled_date);
-- Hot path: volunteers listing open requests.
create index requests_broadcast_idx     on public.requests (created_at)
  where status = 'broadcast';

-- ---------------------------------------------------------------------------
-- trips — 1:1 with an assigned/started request. Two-sided payment.
-- ---------------------------------------------------------------------------
create table public.trips (
  id                    uuid primary key default gen_random_uuid(),
  request_id            uuid not null unique references public.requests (id) on delete cascade,
  started_at            timestamptz,
  ended_at              timestamptz,
  duration_minutes      int,
  hourly_rate_inr       int not null default 135,   -- snapshot of the rate
  amount_inr            int,
  completed_by          uuid references public.profiles (id),
  payment_status        payment_status not null default 'pending',
  requester_paid_at     timestamptz,   -- requester marked "Paid"
  volunteer_received_at timestamptz,   -- volunteer marked "Received"
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index trips_request_idx on public.trips (request_id);

-- ---------------------------------------------------------------------------
-- ratings — mutual; max one per (trip, rater_role)
-- ---------------------------------------------------------------------------
create table public.ratings (
  id         uuid primary key default gen_random_uuid(),
  trip_id    uuid not null references public.trips (id) on delete cascade,
  rater_id   uuid not null references public.profiles (id),
  ratee_id   uuid not null references public.profiles (id),
  rater_role rater_role not null,
  stars      int not null check (stars between 1 and 5),
  feedback   text,
  created_at timestamptz not null default now(),
  unique (trip_id, rater_role)
);

create index ratings_ratee_idx on public.ratings (ratee_id);

-- ---------------------------------------------------------------------------
-- devices — FCM tokens for push fan-out (used from M3)
-- ---------------------------------------------------------------------------
create table public.devices (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  fcm_token  text not null unique,
  platform   text,
  updated_at timestamptz not null default now()
);

create index devices_profile_idx on public.devices (profile_id);

-- ---------------------------------------------------------------------------
-- notifications — optional audit log of sent pushes
-- ---------------------------------------------------------------------------
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  type       text not null,
  payload    jsonb,
  created_at timestamptz not null default now()
);

create index notifications_profile_idx on public.notifications (profile_id);

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger requester_profiles_set_updated_at
  before update on public.requester_profiles
  for each row execute function public.set_updated_at();

create trigger volunteer_profiles_set_updated_at
  before update on public.volunteer_profiles
  for each row execute function public.set_updated_at();

create trigger requests_set_updated_at
  before update on public.requests
  for each row execute function public.set_updated_at();

create trigger trips_set_updated_at
  before update on public.trips
  for each row execute function public.set_updated_at();
