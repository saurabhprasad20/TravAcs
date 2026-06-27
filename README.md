# TravAcs

A cross-platform (Flutter) app connecting visually impaired users ("Requesters")
with verified volunteers ("TravAcsers") for short, paid travel/mobility
assistance. Accessibility-first.

- **Product & requirements:** `docx/appRequirements.md`
- **Engineering principles:** `docx/EngPrinciples.md`
- **Full design (the source of truth):** `docx/design_travacs.md`

## Stack
Flutter + Riverpod (layered: data / domain / presentation, Repository pattern) ·
Supabase (Postgres + Auth + Storage + Realtime + Edge Functions) · phone+OTP auth ·
FCM push (from M3).

## Repository layout
```
app/        Flutter application
supabase/   Version-controlled DB schema (migrations) — see supabase/README.md
admin/      Admin web page (lands in M7)
docx/       Design & requirements docs
```

## Implementation status (see design §17)
| Milestone | Status |
|-----------|--------|
| M0 Scaffold + layered structure | ✅ done |
| M1 DB schema, RLS, phone-OTP auth | ✅ done |
| M2 Profiles, registration, role shell | ✅ done |
| M3 Requests + broadcast + FCM | ⏳ next |
| M4 FCFS accept · M5 Trip OTP/billing · M6 Two-sided payment · M7 Admin · M8 Hardening | ⬜ planned |

What works today: phone-OTP login → one-time complete-profile → role-based
bottom-tab shell (WhatsApp/Instagram style). Requester/Volunteer feature tabs are
accessible placeholders; the Profile tab is fully functional (incl. volunteer
verification status + availability toggle). All backend tables/columns for later
milestones already exist, so no rework is needed.

## Getting started

### 1. Backend (one-time)
Apply the SQL in `supabase/` to the project and enable phone auth — see
[`supabase/README.md`](supabase/README.md).

### 2. Run the app
```powershell
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates freezed/json
# then either:
./run.ps1            # convenience script (copy run.ps1.example first)
# or pass creds directly:
flutter run `
  --dart-define=SUPABASE_URL=https://grtltamvmrgdybmwhszi.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_QCKZDeae68h960cmvfKj8w_FOi1fpLT
```

> The Supabase URL + publishable key are public-by-design (the key ships in the
> client); RLS protects the data. They're passed via `--dart-define` and kept out
> of committed source (`run.ps1` is gitignored).

### Quality gates
```powershell
cd app
flutter analyze      # currently clean
flutter test         # unit tests
```

## Notes
- **No SMS in dev without a gateway:** OTP login requires the Supabase phone
  provider + an SMS gateway (MSG91/Twilio). Until configured, the app builds and
  navigates but can't complete a real login.
- **First admin:** promote a user via SQL — see `supabase/README.md`.
