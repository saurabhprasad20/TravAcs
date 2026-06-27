# TravAcs — Supabase backend

Version-controlled database schema for TravAcs (see `../docx/design_travacs.md`).
There is **no Supabase CLI in this environment**, so migrations are authored as
plain SQL files here and applied by you to the project.

Project: `https://grtltamvmrgdybmwhszi.supabase.co`

## Migrations (apply in order)

| File | What it creates |
|------|-----------------|
| `migrations/0001_init.sql` | Enums, tables (`profiles`, `requester_profiles`, `volunteer_profiles`, `requests`, `trips`, `ratings`, `devices`, `notifications`), indexes, `updated_at` triggers. **No Aadhaar columns** (v1). |
| `migrations/0002_rls.sql` | Enables RLS on every table + the policy matrix (design §5.4) + `is_admin()` / `is_approved_volunteer()` helpers. |
| `migrations/0003_views_and_profile.sql` | `assigned_counterpart_contacts` view, volunteer-verification guard trigger, `upsert_my_profile()` RPC (post-OTP registration), `set_verification()` admin RPC, grants. |

### Option A — Dashboard (no secrets needed)
1. Open the project → **SQL Editor**.
2. Paste and run `0001_init.sql`, then `0002_rls.sql`, then `0003_views_and_profile.sql` (in that order).

### Option B — Supabase CLI (run these yourself; the DB password stays with you)
```bash
npx supabase link --project-ref grtltamvmrgdybmwhszi
npx supabase db push
```

## Configure phone (OTP) auth — required for login
In the dashboard: **Authentication → Providers → Phone** → enable, and configure an
SMS gateway (**MSG91** recommended for India, or Twilio). Without this, OTP send/verify
will fail. Keep gateway keys in the dashboard — never in the app.

## Creating the first admin
Admin accounts can't self-register (the RPC blocks self-assigning `admin`). After a
user signs in once, promote them in the SQL Editor:
```sql
update public.profiles set role = 'admin' where id = '<auth-user-uuid>';
```
The custom admin approve/reject web page lands in milestone M7.

## Later milestones
Request/FCFS/trip/payment RPCs and the FCM broadcast Edge Function (design §6, §8)
arrive in M3–M6 as additional `migrations/*.sql` and `functions/*` here.
