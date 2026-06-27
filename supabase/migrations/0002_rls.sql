-- ============================================================================
-- TravAcs — 0002 RLS: enable row level security + policy matrix (design §5.4)
-- Default-deny: enabling RLS with no matching policy blocks access.
-- Consistency-critical writes (status changes, assignment, payment, ratings)
-- are performed by SECURITY DEFINER RPCs (0003 + later milestones), not by
-- direct client writes.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Authorization helpers. SECURITY DEFINER so they read `profiles` as the
-- function owner and therefore do NOT trigger the profiles RLS policies
-- (avoids infinite recursion in policy expressions).
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_approved_volunteer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.volunteer_profiles
    where profile_id = auth.uid() and verification_status = 'approved'
  );
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS on every table.
-- ---------------------------------------------------------------------------
alter table public.profiles            enable row level security;
alter table public.requester_profiles  enable row level security;
alter table public.volunteer_profiles  enable row level security;
alter table public.requests            enable row level security;
alter table public.trips               enable row level security;
alter table public.ratings             enable row level security;
alter table public.devices             enable row level security;
alter table public.notifications       enable row level security;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create policy profiles_select_own on public.profiles
  for select using (id = auth.uid() or public.is_admin());

create policy profiles_insert_own on public.profiles
  for insert with check (id = auth.uid());

create policy profiles_update_own on public.profiles
  for update using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------------
-- requester_profiles
-- ---------------------------------------------------------------------------
create policy requester_profiles_select on public.requester_profiles
  for select using (profile_id = auth.uid() or public.is_admin());

create policy requester_profiles_insert on public.requester_profiles
  for insert with check (profile_id = auth.uid());

create policy requester_profiles_update on public.requester_profiles
  for update using (profile_id = auth.uid() or public.is_admin())
  with check (profile_id = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------------
-- volunteer_profiles
-- (verification_* columns are guarded by a trigger in 0003 so only admins/the
--  set_verification RPC can change them.)
-- ---------------------------------------------------------------------------
create policy volunteer_profiles_select on public.volunteer_profiles
  for select using (profile_id = auth.uid() or public.is_admin());

create policy volunteer_profiles_insert on public.volunteer_profiles
  for insert with check (profile_id = auth.uid());

create policy volunteer_profiles_update on public.volunteer_profiles
  for update using (profile_id = auth.uid() or public.is_admin())
  with check (profile_id = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------------
-- requests
-- Read: own (as requester or assigned volunteer), or open broadcasts if the
-- caller is an approved volunteer. Create: own broadcasts only. Mutations
-- (accept/start/complete/cancel) go through RPCs.
-- ---------------------------------------------------------------------------
create policy requests_select on public.requests
  for select using (
    requester_id = auth.uid()
    or volunteer_id = auth.uid()
    or (status = 'broadcast' and public.is_approved_volunteer())
    or public.is_admin()
  );

create policy requests_insert_own on public.requests
  for insert with check (
    requester_id = auth.uid()
    and status in ('draft', 'broadcast')
    and volunteer_id is null
  );

-- ---------------------------------------------------------------------------
-- trips — read if a party to the underlying request. Mutations via RPC only.
-- ---------------------------------------------------------------------------
create policy trips_select on public.trips
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.requests r
      where r.id = trips.request_id
        and (r.requester_id = auth.uid() or r.volunteer_id = auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- ratings — insert your own; read ratings you gave or received.
-- (submit_rating RPC is the primary path; unique(trip_id, rater_role) prevents
--  duplicates.)
-- ---------------------------------------------------------------------------
create policy ratings_select on public.ratings
  for select using (
    rater_id = auth.uid() or ratee_id = auth.uid() or public.is_admin()
  );

create policy ratings_insert_own on public.ratings
  for insert with check (rater_id = auth.uid());

-- ---------------------------------------------------------------------------
-- devices — full CRUD over your own FCM tokens.
-- ---------------------------------------------------------------------------
create policy devices_all_own on public.devices
  for all using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- notifications — read your own. Inserts are server-side (service role).
-- ---------------------------------------------------------------------------
create policy notifications_select_own on public.notifications
  for select using (profile_id = auth.uid() or public.is_admin());
