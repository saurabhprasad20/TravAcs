-- ============================================================================
-- TravAcs — 0003 views, profile RPC, verification guard (design §5.4, §6, §7)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- assigned_counterpart_contacts (§5.4)
-- Exposes ONLY the counterpart's name + phone, and ONLY once a request is
-- assigned+. Runs with the view owner's privileges (security_invoker = false)
-- so it can read profiles, but the WHERE clause restricts rows to requests the
-- current user is a party to. This is how contact details are shared without
-- granting broad read access to `profiles`.
-- ---------------------------------------------------------------------------
create view public.assigned_counterpart_contacts
with (security_invoker = false) as
select
  r.id as request_id,
  case when r.requester_id = auth.uid() then r.volunteer_id
       else r.requester_id end as counterpart_id,
  p.full_name,
  p.phone
from public.requests r
join public.profiles p
  on p.id = case when r.requester_id = auth.uid() then r.volunteer_id
                 else r.requester_id end
where r.status in ('assigned', 'started', 'completed', 'closed')
  and (r.requester_id = auth.uid() or r.volunteer_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Guard: only admins (incl. the set_verification RPC, which checks is_admin)
-- may change verification_* columns on volunteer_profiles.
-- ---------------------------------------------------------------------------
create or replace function public.guard_volunteer_verification()
returns trigger
language plpgsql
as $$
begin
  if (new.verification_status is distinct from old.verification_status
       or new.verified_by is distinct from old.verified_by
       or new.verified_at is distinct from old.verified_at
       or new.rejection_reason is distinct from old.rejection_reason)
     and not public.is_admin() then
    raise exception 'verification fields can only be changed by an admin'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger volunteer_verification_guard
  before update on public.volunteer_profiles
  for each row execute function public.guard_volunteer_verification();

-- ---------------------------------------------------------------------------
-- upsert_my_profile (§7) — create/update the caller's profile + role row after
-- phone-OTP sign-in. Role cannot be self-assigned as admin and cannot be
-- changed once set (prevents role flipping).
-- ---------------------------------------------------------------------------
create or replace function public.upsert_my_profile(
  p_role               user_role,
  p_full_name          text,
  p_gender             gender_type default null,
  p_date_of_birth      date        default null,
  p_phone              text        default null,
  p_address            text        default null,
  p_home_location_text text        default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid          uuid := auth.uid();
  v_actual_role  user_role;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_role = 'admin' then
    raise exception 'cannot self-assign admin role' using errcode = '42501';
  end if;

  insert into public.profiles (id, role, full_name, gender, date_of_birth, phone)
  values (v_uid, p_role, p_full_name, p_gender, p_date_of_birth, p_phone)
  on conflict (id) do update
    set full_name     = excluded.full_name,
        gender        = excluded.gender,
        date_of_birth = excluded.date_of_birth,
        phone         = excluded.phone
  returning role into v_actual_role;

  -- Use the stored role (which may pre-exist) for the role-specific row.
  if v_actual_role = 'requester' then
    insert into public.requester_profiles (profile_id, home_location_text)
    values (v_uid, p_home_location_text)
    on conflict (profile_id) do update
      set home_location_text = excluded.home_location_text;
  elsif v_actual_role = 'volunteer' then
    insert into public.volunteer_profiles (profile_id, address)
    values (v_uid, p_address)
    on conflict (profile_id) do update
      set address = excluded.address;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- set_verification (§6, §12) — admin approves/rejects a volunteer. Out-of-band
-- identity check; no Aadhaar handled in v1.
-- ---------------------------------------------------------------------------
create or replace function public.set_verification(
  p_profile_id uuid,
  p_decision   verification_status,
  p_reason     text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;
  if p_decision not in ('approved', 'rejected') then
    raise exception 'invalid decision' using errcode = '22023';
  end if;

  update public.volunteer_profiles
     set verification_status = p_decision,
         verified_by         = auth.uid(),
         verified_at         = now(),
         rejection_reason    = case when p_decision = 'rejected' then p_reason
                                    else null end
   where profile_id = p_profile_id;

  if not found then
    raise exception 'volunteer not found' using errcode = 'P0002';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants (Supabase exposes these to the `authenticated` role via PostgREST).
-- ---------------------------------------------------------------------------
grant select on public.assigned_counterpart_contacts to authenticated;
grant execute on function public.upsert_my_profile(
  user_role, text, gender_type, date, text, text, text) to authenticated;
grant execute on function public.set_verification(
  uuid, verification_status, text) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_approved_volunteer() to authenticated;
