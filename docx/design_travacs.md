# TravAcs — End-to-End Development Design

> **Status:** Approved design for v1 (initial release).
> **Audience:** Engineering team building TravAcs one-shot, top-to-bottom.
> **Companion docs:** `appRequirements.md` (product vision & requirements), `EngPrinciples.md` (engineering standards).
> **How to use this document:** Sections 1–16 are the *what & how*. Section 17 is the *build order* — follow it sequentially. Each milestone is self-contained and depends only on earlier milestones, so the app can be built without going back and forth.

---

## 0. Locked Decisions (read first)

These decisions are final for v1. Everything below assumes them.

| # | Area | Decision | Why |
|---|------|----------|-----|
| 1 | **Mobile** | **Flutter** (Android + iOS, single codebase) | Required by constraints; strong a11y. |
| 2 | **Backend** | **Supabase** (Postgres, Auth, Storage, Realtime, Edge Functions) | Low cost, fast dev, fits <1000 users. |
| 3 | **Push** | **Firebase Cloud Messaging (FCM)** | New-request / assignment / trip updates. |
| 4 | **Auth** | **Phone number + OTP** as the primary login (Supabase Auth phone provider + an SMS gateway — **MSG91** recommended for India, or Twilio). Wrapped behind an `AuthRepository` abstraction; **email+password** is a future alternate login. | Phone-centric audience; matches docs. |
| 5 | **Admin** | **Supabase Studio** for ops + a **minimal custom web page** for volunteer approve/reject (decision-only). | Cheapest, fastest; no second heavy codebase. |
| 6 | **Matching** | **Broadcast to all active/available volunteers**; FCFS decides. Schema is **geo-ready** (lat/long + `service_area`) for later PostGIS radius matching. | Simplest correct model at this scale. |
| 7 | **App architecture** | **Riverpod** (DI + state) + **layered** (data / domain / presentation) + **Repository pattern**. | SOLID, testable, low boilerplate. |
| 8 | **Aadhaar / Verification** | **No Aadhaar data captured or stored in v1** (images or number) — compliance is deferred. Volunteers are verified **manually / out-of-band** by admin, who toggles `approved`/`rejected`. Aadhaar capture is a documented **future** feature. | Avoid PII/compliance burden now. |
| 9 | **Billing & Payment** | ₹135/hour, **pro-rated per minute**: `amount = round(duration_minutes / 60 * 135)`. Payment external (UPI) with **two-sided confirmation**: Requester marks **Paid**, Volunteer marks **Received**; settled only when both. | Matches requirements; mutual trust. |
| 10 | **FCFS** | Enforced server-side by a **single atomic conditional `UPDATE`** in a Postgres RPC. First writer wins; others get "already taken." | Guaranteed consistency. |
| 11 | **Trip start** | **6-digit OTP** generated on assignment, stored **hashed**, shown to Requester, entered+verified by volunteer server-side. | Proof both parties met. |

---

## 1. Introduction & Goals

### 1.1 Product summary
TravAcs connects **visually impaired users ("Requesters")** with **verified volunteers ("TravAcsers")** who provide short-duration, paid travel/mobility assistance (e.g., home → metro station). v1 prioritizes **accessibility, reliability, simplicity, and low cost** over feature richness.

### 1.2 Success criteria (v1)
A user can end-to-end:
1. Register as Requester or Volunteer.
2. Volunteer completes Aadhaar verification (admin-approved).
3. Requester creates an assistance request.
4. A volunteer accepts (FCFS, server-guaranteed single winner).
5. Trip starts via OTP and is completed; duration & amount computed.
6. Payment coordinated externally (UPI) and confirmed.
7. Both parties rate each other.
8. The entire Requester flow is fully usable with a screen reader.

### 1.3 In scope (v1)
Registration, profiles, request lifecycle, FCFS assignment, OTP trip start, completion + billing calc, external-payment confirmation, mutual ratings, push notifications, admin verification, accessibility.

### 1.4 Explicit non-goals (v1)
- ❌ In-app payments / wallet / commission.
- ❌ Real-time GPS live tracking on a map.
- ❌ Aadhaar capture/storage (verification is manual/out-of-band for v1; Aadhaar feature deferred for compliance).
- ❌ Email+password login (phone+OTP only in v1; email is a future alternate).
- ❌ Geo-radius matching (broadcast-all for now; geo-ready schema).
- ❌ In-app chat (parties use phone numbers shared on assignment).
- ❌ Large-scale infra / multi-region.

### 1.5 Key constraints (from requirements)
Single codebase; minimal infra cost; <1000 users initially; production-grade quality; accessibility is mandatory, not optional. **One recurring cost is accepted:** per-SMS charges for phone-OTP auth via the SMS gateway (negligible at <1000 users).

---

## 2. High-Level Architecture

```
┌─────────────────────────────┐        ┌──────────────────────────────────────────┐
│        Flutter App          │        │                 Supabase                   │
│  (Android / iOS)            │        │                                            │
│                             │  HTTPS │  ┌────────────┐   ┌──────────────────────┐ │
│  presentation (Riverpod)    │◄──────►│  │ Auth (JWT) │   │ Postgres + RLS       │ │
│  domain (use cases/models)  │  REST  │  └────────────┘   │  profiles, requests, │ │
│  data (repos + Supabase SDK)│  +RT   │  ┌────────────┐   │  trips, ratings...   │ │
│                             │        │  │ Storage    │   └──────────────────────┘ │
│  ┌───────────────────────┐  │        │  │ (unused v1 │   ┌──────────────────────┐ │
│  │ FCM SDK (push tokens) │  │        │  │  reserved) │   │ Edge Functions / RPC │ │
│  └───────────┬───────────┘  │        │  └────────────┘   │ accept_request,      │ │
└──────────────┼──────────────┘        │  ┌────────────┐   │ start_trip,          │ │
               │                       │  │ Realtime   │   │ complete_trip, ...   │ │
               │   push                │  └────────────┘   └───────────┬──────────┘ │
               │                       └──────────────────────────────┼────────────┘
        ┌──────▼───────┐                                       fan-out │ (server key)
        │     FCM      │◄──────────────────────────────────────────────┘
        └──────────────┘
                                  ┌──────────────────────────────┐
                                  │  Minimal Admin Web Page      │
                                  │  (volunteer approve/reject)  │──► Supabase (admin role)
                                  └──────────────────────────────┘
```

**Trust boundaries**
- The **Flutter client is untrusted**: it only ever uses the *anon* key + a logged-in user JWT. RLS enforces what each user can read/write.
- **Mutating, consistency-critical operations** (accept, start, complete, mark-paid, mark-received, submit rating, broadcast) run **server-side** as `SECURITY DEFINER` RPCs / Edge Functions. The client never updates `status`, `volunteer_id`, `amount`, `payment_status`, or `verification_status` directly.
- **Storage** is provisioned but **not used in v1** (no Aadhaar capture); reserved for the future verification-document feature.
- **FCM server key** and **service-role key** live only in Edge Function secrets / admin backend — never in the app.
- **Admin** uses a separate authenticated context with an `admin` role; the only privileged client surface.

---

## 3. Technology Stack & Rationale

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Mobile UI | Flutter 3.x (stable) | Single codebase, mature a11y (`Semantics`). |
| State / DI | **Riverpod** (`flutter_riverpod`, `riverpod_annotation`) | Compile-safe DI, testable, less boilerplate than Bloc. |
| Backend | Supabase (`supabase_flutter`) | Auth + Postgres + Storage + Realtime + Functions in one. |
| Auth | Supabase **phone provider** + SMS gateway (**MSG91** for India, or Twilio) | Phone+OTP primary login. |
| DB | PostgreSQL (managed by Supabase) | Relational integrity, RLS, transactions for FCFS. |
| Server logic | Postgres RPC (PL/pgSQL) + Supabase Edge Functions (TypeScript/Deno) | Atomic DB ops in RPC; external calls (FCM) in Edge Functions. |
| Push | FCM (`firebase_messaging`, `firebase_core`) | Cross-platform push. |
| Routing | `go_router` | Declarative, deep-link & redirect friendly (auth/role gating). |
| Models | `freezed` + `json_serializable` | Immutable models, value equality, safe JSON. |
| Forms/validation | Flutter form + small validators in domain layer | Keep rules testable & UI-agnostic. |
| Storage | Supabase Storage (private buckets) | Reserved; **unused in v1** (Aadhaar deferred). |
| Admin web | Plain HTML/JS (or tiny React+Vite) calling Supabase JS SDK | Minimal surface; ships fast. |
| Tests | `flutter_test`, `mocktail`, `integration_test` | Unit/widget/integration coverage. |

> Add specific package versions to `pubspec.yaml` at build time; pin to current stable.

---

## 4. Domain Model & Roles

### 4.1 Roles
- **Requester** (visually impaired user) — creates requests, starts/ends trips, rates, pays externally.
- **TravAcser** (volunteer) — verifies via Aadhaar, accepts requests, runs the trip, confirms payment, rates.
- **Admin** — approves/rejects volunteer verification; ops oversight.

A `profiles.role` enum (`requester` | `volunteer` | `admin`) is the single source of truth, set at registration (admin assigned out-of-band).

### 4.2 Request lifecycle (state machine)
```
 draft ──submit──► broadcast ──accept(FCFS)──► assigned ──verifyOTP──► started ──complete──► completed ──rate(both)──► closed
   │                   │                          │                       │
   └──cancel──►cancelled  └──(timeout/cancel)──►cancelled   └──cancel──►cancelled (pre-start only)
```
- **draft** → optional client-side staging; may be skipped (create directly as `broadcast`).
- **broadcast** → visible to all eligible volunteers; FCM fan-out sent.
- **assigned** → exactly one volunteer attached (atomic); contact details exchanged; OTP generated.
- **started** → OTP verified, `started_at` recorded.
- **completed** → trip ended, `ended_at`, `duration_minutes`, `amount` recorded.
- **closed** → both ratings submitted (or rating window passed).
- **cancelled** → terminal; allowed only before `started`.

Allowed transitions are enforced **server-side** in the RPCs (reject any out-of-order transition).

### 4.3 Volunteer verification (state machine)
```
 pending ──admin approve──► approved
    │
    └──admin reject──► rejected ──(admin re-review)──► pending
```
Verification is **manual / out-of-band** in v1: the app captures **no Aadhaar data**. A volunteer's profile starts `pending`; the admin verifies identity through an external process (offline document check, call, etc.) and toggles `approved`/`rejected` (with an optional reason) in the admin page. Only `approved` volunteers can see/accept requests (enforced in `accept_request` and the available-requests query/RLS).

---

## 5. Database Design (PostgreSQL)

> All tables in schema `public`. UUID PKs (`gen_random_uuid()`), `created_at`/`updated_at timestamptz default now()`. RLS **enabled on every table** (Section 5.4). Enums defined first.

### 5.1 Enums
```sql
create type user_role         as enum ('requester','volunteer','admin');
create type gender_type        as enum ('male','female','other','prefer_not_to_say');
create type verification_status as enum ('pending','approved','rejected');
create type request_status     as enum ('draft','broadcast','assigned','started','completed','closed','cancelled');
create type payment_status     as enum ('pending','awaiting_other','confirmed');
create type rater_role         as enum ('requester','volunteer');
```

### 5.2 Tables

**`profiles`** — one row per auth user (PK = `auth.users.id`).
| column | type | notes |
|--------|------|-------|
| id | uuid PK | = `auth.uid()` |
| role | user_role | not null |
| full_name | text | not null |
| gender | gender_type | |
| date_of_birth | date | |
| phone | text | shared with counterpart on assignment |
| is_active | boolean | default true (volunteer availability toggle) |
| created_at / updated_at | timestamptz | |

**`volunteer_profiles`** — 1:1 with a volunteer `profiles` row.
| column | type | notes |
|--------|------|-------|
| profile_id | uuid PK FK→profiles.id | |
| address | text | |
| verification_status | verification_status | default 'pending' (**no Aadhaar data stored in v1**) |
| verified_by | uuid FK→profiles.id (admin) | nullable |
| verified_at | timestamptz | nullable |
| rejection_reason | text | nullable |
| rating_avg | numeric(2,1) | denormalized, updated on rating |
| rating_count | int | default 0 |

**`requester_profiles`** — 1:1 with a requester `profiles` row.
| column | type | notes |
|--------|------|-------|
| profile_id | uuid PK FK→profiles.id | |
| home_location_text | text | optional saved location |
| home_lat / home_lng | double precision | nullable (geo-ready) |
| rating_avg | numeric(2,1) | |
| rating_count | int | default 0 |

**`requests`** — the core entity.
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| requester_id | uuid FK→profiles.id | not null |
| volunteer_id | uuid FK→profiles.id | nullable until assigned |
| status | request_status | not null default 'broadcast' |
| scheduled_date | date | not null |
| start_time | time | not null |
| expected_duration_minutes | int | not null |
| pickup_text | text | not null |
| pickup_lat / pickup_lng | double precision | nullable (geo-ready) |
| destination_text | text | not null |
| dest_lat / dest_lng | double precision | nullable |
| requirements | text | assistance needs |
| instructions | text | nullable |
| otp_hash | text | nullable; set on assignment |
| service_area | text | nullable; geo-ready filter |
| created_at / updated_at | timestamptz | |

Indexes: `(status)`, `(requester_id)`, `(volunteer_id)`, `(scheduled_date)`, partial index `where status='broadcast'`.

**`trips`** — 1:1 with an assigned/started request (split from `requests` to keep request immutable-ish & query timings cleanly).
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| request_id | uuid FK→requests.id unique | not null |
| started_at | timestamptz | nullable |
| ended_at | timestamptz | nullable |
| duration_minutes | int | computed on complete |
| hourly_rate_inr | int | snapshot = 135 |
| amount_inr | int | computed |
| completed_by | uuid FK→profiles.id | who pressed complete |
| payment_status | payment_status | default 'pending' → `awaiting_other` (one side marked) → `confirmed` (both marked) |
| requester_paid_at | timestamptz | nullable; set when requester marks **Paid** |
| volunteer_received_at | timestamptz | nullable; set when volunteer marks **Received** |
| created_at / updated_at | timestamptz | |

> Snapshotting `hourly_rate_inr` per trip means future rate changes don't rewrite history.

**`ratings`** — mutual; max one per (trip, rater_role).
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| trip_id | uuid FK→trips.id | not null |
| rater_id | uuid FK→profiles.id | |
| ratee_id | uuid FK→profiles.id | |
| rater_role | rater_role | not null |
| stars | int check (1..5) | not null |
| feedback | text | nullable |
| created_at | timestamptz | |
| | unique(trip_id, rater_role) | one rating per side |

**`devices`** — FCM tokens for fan-out.
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| profile_id | uuid FK→profiles.id | |
| fcm_token | text unique | |
| platform | text | 'android'/'ios' |
| updated_at | timestamptz | |

**`notifications`** (optional audit) — log of sent pushes for debugging/observability.
| id | profile_id | type | payload jsonb | created_at |

### 5.3 Derived/computed rules
- `duration_minutes = round(extract(epoch from (ended_at - started_at))/60)`; floor at 1.
- `amount_inr = round(duration_minutes / 60.0 * hourly_rate_inr)`.
- **Payment is two-sided**: `payment_status = 'pending'` when neither timestamp set, `'awaiting_other'` when exactly one of `requester_paid_at`/`volunteer_received_at` is set, `'confirmed'` only when **both** are set. Derived inside the `mark_paid`/`mark_received` RPCs.
- Rating aggregates updated transactionally in `submit_rating` (recompute avg/count on the ratee profile).

### 5.4 Row Level Security (policy matrix)

| Table | Requester | Volunteer | Admin | Notes |
|-------|-----------|-----------|-------|-------|
| profiles | R/W own | R/W own; **read counterpart of an assigned request** (via view) | all | No cross-user reads except assigned counterpart. |
| volunteer_profiles | – | R/W own (cannot set `verification_status`) | all | `verification_status` writable **only** by admin/RPC. |
| requester_profiles | R/W own | read counterpart (assigned) | all | |
| requests | R/W own (create; cancel pre-start) | **read** where `status='broadcast'` AND volunteer approved; read own assigned | all | Status changes only via RPC. |
| trips | read own (as requester) | read own (as volunteer) | all | Mutations via RPC only. |
| ratings | insert own as requester; read own | insert own as volunteer; read own | all | One per side enforced by unique constraint. |
| devices | R/W own | R/W own | all | |
| notifications | read own | read own | all | Insert by server only. |

Implementation notes:
- Use `auth.uid()` in policies.
- Consistency-critical writes go through `SECURITY DEFINER` functions that **bypass RLS but re-check authorization internally** (e.g., "is caller an approved volunteer?", "is caller the requester of this request?").
- A safe **view** `assigned_counterpart_contacts` exposes only `full_name` + `phone` of the counterpart once a request is `assigned`+, so contact sharing doesn't require broad `profiles` read access.

---

## 6. Server-Side Logic (RPC / Edge Functions)

All are idempotent where noted and return a typed result `{ ok: boolean, code: string, data?: ... }`. **Status transitions are validated inside each function.**

### 6.1 `accept_request(request_id)` — Postgres RPC (`SECURITY DEFINER`) — **FCFS core**
```sql
-- pseudocode
1. caller := auth.uid()
2. assert caller is a volunteer with verification_status='approved' (else code='NOT_APPROVED')
3. UPDATE requests
     SET volunteer_id = caller,
         status = 'assigned',
         otp_hash = crypt(:plain_otp, gen_salt('bf')),
         updated_at = now()
     WHERE id = request_id
       AND status = 'broadcast'
       AND volunteer_id IS NULL
     RETURNING id;          -- the atomic guard
4. if 0 rows updated -> return { ok:false, code:'ALREADY_TAKEN' }
5. INSERT into trips(request_id, hourly_rate_inr=135)
6. return { ok:true, code:'ASSIGNED' }   -- plain OTP delivered to REQUESTER only (step below)
```
- The **single conditional UPDATE is the concurrency guarantee** — Postgres row locking makes exactly one concurrent caller succeed; the rest match 0 rows.
- The **plain OTP is generated server-side** and stored hashed; it is delivered to the **Requester's** client (via the request payload visible only to the requester), never to the volunteer.
- After success, an Edge Function fans out an "assignment" push to both parties (contact details for each other).

### 6.2 `start_trip(request_id, otp)` — RPC
- Assert caller is the assigned volunteer; request `status='assigned'`.
- Verify `otp` against `otp_hash` (`crypt`). On mismatch → `OTP_INVALID` (rate-limit attempts: max 5).
- Set `requests.status='started'`, `trips.started_at=now()`. Return ok. Push "trip started" to requester.

### 6.3 `complete_trip(request_id)` — RPC
- Assert caller is requester **or** assigned volunteer; status `started`.
- Set `ended_at=now()`, compute `duration_minutes`, `amount_inr` (Section 5.3), `requests.status='completed'`, `completed_by=caller`.
- Return `{ amount_inr, duration_minutes }`. Push "trip completed + amount" to both.

### 6.4 Payment — two-sided confirmation (two RPCs)
**`mark_paid(request_id)`** — caller must be the **requester** of a `completed` trip. Sets `requester_paid_at=now()` (idempotent). Recomputes `payment_status` (Section 5.3). Pushes `payment_marked` to the volunteer ("Requester marked Paid").

**`mark_received(request_id)`** — caller must be the **assigned volunteer** of a `completed` trip. Sets `volunteer_received_at=now()` (idempotent). Recomputes `payment_status`. Pushes `payment_marked` to the requester ("Volunteer marked Received").

When **both** timestamps are set, `payment_status='confirmed'` and a `payment_confirmed` push goes to both parties. Neither side can set the other's flag (enforced by the role check). Marking is **completion-of-trust only** — it does not move money (payment is external UPI).

### 6.5 `submit_rating(request_id, stars, feedback)` — RPC
- Assert caller is a party to the trip; trip `completed`/`closed`.
- Derive `rater_role`, `ratee_id`. Insert rating (unique per side). Recompute ratee aggregates.
- If both sides have rated → set `requests.status='closed'`. Return ok.

### 6.6 `broadcast_request(request_id)` — Edge Function (TypeScript)
- Triggered after request creation (client calls it, or DB trigger → function).
- Loads FCM tokens of **all approved, active volunteers** (later: filtered by `service_area`/geo).
- Sends FCM data+notification messages (pickup, destination, timing, duration). Writes `notifications` audit rows. Best-effort; failures logged, not fatal to request creation.

### 6.7 Error contract (shared)
`code` values: `NOT_AUTHENTICATED`, `NOT_APPROVED`, `FORBIDDEN`, `ALREADY_TAKEN`, `INVALID_STATE`, `OTP_INVALID`, `RATE_LIMITED`, `NOT_FOUND`, `OK`. The client maps each to an accessible, screen-reader-announced message.

---

## 7. Authentication & Authorization

- **Supabase Auth, phone number + OTP (primary).** Flow: user enters phone → `signInWithOtp(phone)` sends an SMS code via the configured gateway (**MSG91**/Twilio in the Supabase phone provider) → user enters code → `verifyOtp` returns a session. The phone number is the primary identity (`auth.users.phone` ↔ `profiles.phone`).
- **First-time sign-up vs login** is unified: same OTP flow; if no `profiles` row exists post-verify, the app routes to a one-time **complete-profile** step (role choice + name/gender/DOB/address) which creates the `profiles` (+ role-specific) row via a post-verify RPC or `handle_new_user` trigger.
- **Session**: `supabase_flutter` persists/refreshes JWT; app boots into a splash that resolves auth + profile + role, then routes.
- **`AuthRepository` abstraction** (domain interface) with a `SupabaseAuthRepository` implementation. Methods: `requestOtp(phone)`, `verifyOtp(phone, code)`, `signOut`, `currentUser`, `onAuthStateChanged`. **Email+password later** = add `signInWithEmail`/`signUpWithEmail` to the same interface + extend the impl; **domain & UI untouched**.
- **OTP UX/security**: resend cooldown, attempt limits, and accessible code entry (Section 11). SMS-OTP rate limiting relies on Supabase Auth + gateway controls.
- **Authorization** = RLS + in-RPC checks (Section 5.4 / 6). The client never trusts itself for permission decisions.
- **Role gating** in `go_router` redirect: unauthenticated → auth flow; volunteer not-approved → limited shell (verification screen only for request features).

---

## 8. Notifications

- **FCM setup**: `firebase_core` + `firebase_messaging`; Android `google-services.json`, iOS `GoogleService-Info.plist` + APNs key. Request notification permission (iOS/Android 13+) with an accessible rationale.
- **Token lifecycle**: on login & on token refresh, upsert into `devices` (`profile_id`, `fcm_token`, `platform`). Remove on logout.
- **Message types** (data payload `type`): `new_request`, `assignment`, `trip_started`, `trip_completed`, `payment_marked` (one side marked Paid/Received), `payment_confirmed` (both sides marked), `rating_received`, `verification_result`.
- **Server fan-out** via `broadcast_request` Edge Function + targeted sends from other RPCs' companion functions, using the FCM server key (secret).
- **In-app Realtime fallback**: clients subscribe (Supabase Realtime) to their own `requests`/`trips` rows so status changes reflect live even if a push is missed. Realtime is the source of truth for **UI state**; FCM is for **wake/alert**.
- **Accessibility**: every notification tap deep-links (`go_router`) to the relevant screen; in-app changes are announced via `SemanticsService.announce`.

---

## 9. Flutter App Architecture

### 9.1 Folder structure
```
lib/
  main.dart
  app.dart                      # MaterialApp.router, theme, a11y config
  core/
    config/                     # env, supabase init, constants (rate=135)
    error/                      # Failure types, Result<T>
    router/                     # go_router + redirects (auth/role)
    theme/                      # high-contrast, large-text-friendly theme
    utils/                      # validators, formatters, otp display
    accessibility/              # semantic helpers, announce()
  data/
    models/                     # freezed DTOs + json
    datasources/                # SupabaseClient wrappers (auth, db, storage, rpc)
    repositories/               # *RepositoryImpl (implements domain interfaces)
  domain/
    entities/                   # pure domain models
    repositories/               # abstract interfaces (AuthRepository, RequestRepository...)
    usecases/                   # CreateRequest, AcceptRequest, StartTrip, CompleteTrip...
  presentation/
    providers/                  # Riverpod providers (DI wiring)
    features/
      auth/                     # screens + controllers (Notifier)
      requester/                # tabs: new_request, my_requests, history, profile
      volunteer/                # tabs: available, my_trips, earnings, profile
      shared/                   # rating, trip_detail, otp widgets
```

### 9.2 Layer responsibilities (SOLID)
- **domain** — pure Dart: entities, repository **interfaces**, use cases (one responsibility each). No Flutter/Supabase imports. Fully unit-testable.
- **data** — implements domain interfaces against Supabase; maps DTO↔entity; converts errors to `Failure`. Repository pattern isolates the SDK (Dependency Inversion).
- **presentation** — Riverpod `Notifier`/`AsyncNotifier` controllers call use cases; widgets render state. No business logic in widgets.
- **DI** — Riverpod providers wire datasource → repository impl → use case → controller. Swappable in tests via `ProviderScope` overrides.

### 9.3 Error & result handling
- Use a `Result<T> = Success<T> | Failure` (or `fpdart`/`Either`) returned by repositories/use cases. Controllers translate into `AsyncValue`. Every `Failure` carries an accessible, user-facing message + the server `code`.

### 9.4 Configuration
- `--dart-define` for `SUPABASE_URL`, `SUPABASE_ANON_KEY`, env name. No secrets in source. Hourly rate (`135`) is a server snapshot but mirrored as a display constant.

---

## 10. App Navigation & Screens

### 10.1 Shell — WhatsApp/Instagram style
A persistent **bottom `NavigationBar`** over an **`IndexedStack`** (preserves each tab's state; one widget subtree per tab). The visible body changes by selected tab; the bar stays fixed. Tabs differ by role (resolved at login).

### 10.2 Requester tabs
| Tab | Screen | Purpose / requirement mapping |
|-----|--------|-------------------------------|
| 1. Home | **New Request** | Step 2: date, start time, duration, pickup, destination, requirements, instructions → create + `broadcast_request`. |
| 2. Requests | **My Requests** | Live status (Realtime): broadcast/assigned/started/completed. Shows assigned volunteer contact + **OTP to share** once assigned. Actions: "Complete trip", **"Mark as Paid"** (after completion), "Rate". |
| 3. History | **Trip History** | Past trips, amounts, ratings given. |
| 4. Profile | **Profile** | Edit profile, saved home location, sign out. |

### 10.3 Volunteer tabs
| Tab | Screen | Purpose |
|-----|--------|---------|
| 1. Available | **Available Requests** | Live list of `broadcast` requests; **Accept** → `accept_request` (FCFS). Disabled until verified. |
| 2. Trips | **My Trips** | Assigned/active: requester contact, **Enter OTP → Start**, **Complete**, **Mark as Received** (payment), **Rate**. |
| 3. Earnings | **Earnings/History** | Completed trips + amounts + ratings received. |
| 4. Profile | **Profile + Verification** | See verification status `pending/approved/rejected` + reason (verification handled by admin out-of-band — **no Aadhaar upload in v1**); availability toggle (`is_active`). |

### 10.4 Cross-cutting screens
Splash/auth-resolver, Sign in, Sign up (role pick), Trip detail, Rating sheet (1–5 + feedback), OTP entry (volunteer) / OTP display (requester).

### 10.5 Requirement → screen traceability
| Requirement step | Screen/action |
|---|---|
| 1 Registration | Phone+OTP login → complete-profile (role) + profile creation |
| 2 Request creation | Requester New Request |
| 3 Notification | `broadcast_request` → FCM → volunteer Available tab |
| 4 Acceptance (FCFS) | Volunteer Accept → `accept_request` |
| 5 Assignment confirm | Contact exchange on both Requests/Trips screens |
| 6 Trip start (OTP) | Requester shows OTP / Volunteer enters → `start_trip` |
| 7 Completion | Either party → `complete_trip` (amount shown) |
| 8 Payment | External UPI; Requester `mark_paid` + Volunteer `mark_received` (two-sided) |
| 9 Ratings | Rating sheet both sides → `submit_rating` |

---

## 11. Accessibility Design (first-class)

The **Requester is blind** — their entire flow must be screen-reader-complete; the volunteer flow must also be accessible.

- **Semantics**: every interactive widget has a clear `Semantics(label, hint)`; images/icons have labels; decorative elements `excludeSemantics`.
- **Screen-reader-first Requester flows**: New Request and OTP sharing designed for TalkBack/VoiceOver linear traversal; logical **focus order**; group related fields.
- **Announcements**: status changes, errors, and successes use `SemanticsService.announce()` (e.g., "Volunteer assigned. Your OTP is 4 8 2 1 0 7", read digit-by-digit).
- **No color-only cues**: status conveyed by text/icon + label, not color alone; meets WCAG AA contrast in the theme.
- **Targets & text**: ≥48dp touch targets; supports OS large-font/bold-text without breaking layout (avoid fixed heights; use scalable text).
- **Forms**: every field labeled + error text announced; time/date pickers have accessible alternatives (text entry fallback).
- **OTP (two contexts)**: (a) **login OTP** — phone & SMS-code entry fields fully labeled, with autofill/SMS-autoread where available and an accessible resend control; (b) **trip-start OTP** — display screen reads digits individually; entry screen labels each box.
- **Validation checklist** (in `EngPrinciples` spirit) per release: full Requester journey with TalkBack (Android) and VoiceOver (iOS); keyboard/switch navigation; large-text mode; high-contrast mode.
- **Automated a11y tests**: `flutter_test` accessibility guidelines checks (`meetsGuideline(textContrastGuideline, labeledTapTargetGuideline, androidTapTargetGuideline)`).

---

## 12. Admin Panel

### 12.1 Supabase Studio (ops)
Day-to-day data inspection, manual fixes, and analytics SQL run in Studio with the project owner account. Used for: viewing requests/trips, supporting users, ad-hoc reports.

### 12.2 Minimal custom verification page
A single-purpose web page (plain HTML/JS or a tiny React+Vite app) for **volunteer approve/reject** (decision-only — **no Aadhaar/document handling in v1**).

- **Auth**: admin signs in via Supabase Auth; `profiles.role='admin'`.
- **List**: query `volunteer_profiles where verification_status='pending'` (admin RLS allows) with the volunteer's name/phone/address.
- **Review**: admin verifies identity through an **external/out-of-band process** (offline document check, phone call, etc.) — the app shows no Aadhaar.
- **Decision**: calls an admin-only RPC `set_verification(profile_id, decision, reason?)` that sets `verification_status`, `verified_by`, `verified_at`, optional `rejection_reason`, and pushes `verification_result` to the volunteer.
- **Security**: page uses the **anon key + admin JWT** only; never the service-role key in the browser. All privileged writes go through the RPC with internal role checks.
- **Future**: when Aadhaar capture returns, add a private-bucket upload + short-TTL signed-URL preview here.

---

## 13. Security & Privacy

- **RLS on every table** (Section 5.4); default-deny.
- **Consistency-critical writes only via `SECURITY DEFINER` RPCs** with internal authorization — clients can't set `status`, `volunteer_id`, `amount`, `verification_status`, `payment_status`, or the payment timestamps.
- **No Aadhaar / minimal PII**: v1 stores **no Aadhaar image or number** (compliance deferred). Identity verification is manual/out-of-band; only `verification_status` is persisted. This sharply reduces PII exposure.
- **Auth (phone+OTP)**: SMS-OTP issued/verified by Supabase Auth + gateway; rely on provider rate-limiting + app-side resend cooldown to deter abuse. Phone numbers are PII — protected by RLS like other profile data.
- **PII minimization**: counterpart contact (`name`,`phone`) exposed **only after assignment**, via the restricted `assigned_counterpart_contacts` view.
- **Trip OTP** stored hashed (`crypt`/bcrypt); attempt rate-limiting; never sent to the volunteer. (Distinct from the login SMS OTP.)
- **Secrets**: FCM server key, SMS-gateway key, and service-role key only in Edge Function/admin secrets; app ships only anon key.
- **Transport**: HTTPS/TLS everywhere (Supabase default).
- **Safety for vulnerable users**: only **verified** volunteers can accept; mutual ratings build trust; design hook for future "report user"/block. Cancellations allowed pre-start.
- **Data retention**: no Aadhaar data to retain in v1; trip/rating data retained for history. (Aadhaar retention policy to be defined when that feature returns.)
- **Input validation** both client (UX) and server (trust) sides.

---

## 14. Error Handling, Logging & Monitoring

- **Client**: repositories convert exceptions → typed `Failure`; controllers surface accessible messages + announce; no raw stack traces to users. Global error boundary logs to console/crash reporting.
- **Crash/observability**: integrate Sentry or Firebase Crashlytics (low cost) for the app; Supabase logs (Postgres/Edge Function) for backend; `notifications` table as a push-audit trail.
- **Graceful degradation**: Realtime drop → fall back to pull-to-refresh; FCM miss → Realtime/refresh still updates state; offline → cached read where safe, clear "no connection" announcements; all mutating actions are **idempotent** so retries are safe.
- **FCFS race observability**: log `ALREADY_TAKEN` counts to validate the model under load.

---

## 15. Testing Strategy

Per `EngPrinciples` (unit testing for business-critical workflows):

- **Unit (domain/data)** — highest priority:
  - **FCFS**: simulate concurrent `accept_request` (integration against a test DB) → exactly one success.
  - **Billing**: `amount_inr` across durations (1 min, 59 min, 60, 90, 135) — boundary/rounding.
  - **OTP**: hash/verify, wrong-OTP rate limit, state guards.
  - **Two-sided payment**: `mark_paid`/`mark_received` each idempotent; `payment_status` only `confirmed` when both timestamps set; role checks (requester can't mark received & vice-versa).
  - **State machine**: reject illegal transitions in every RPC.
  - Repository mapping & error translation (with `mocktail`).
- **Widget** — New Request form validation, Available→Accept, OTP entry/display, Rating sheet.
- **Accessibility** — `meetsGuideline` checks on key screens; manual TalkBack/VoiceOver pass per release (Section 11 checklist).
- **Integration** (`integration_test`) — happy path: phone-OTP login → complete profile → create → accept → trip-OTP start → complete → mark paid + mark received → rate → closed.
- **Backend** — pgTAP or SQL tests for RLS (each role can/can't do the right things) and RPCs.
- **Coverage target**: business-critical paths (accept/start/complete/billing/RLS) ~100%; overall pragmatic.

---

## 16. Environments, Config & CI/CD

- **Two Supabase projects**: `dev` and `prod` (separate keys/URLs via `--dart-define`).
- **Phone auth provider**: configure the Supabase Auth **phone provider** with the SMS gateway (MSG91/Twilio) credentials per environment; keep `dev` on a test/low-volume sender. Gateway keys stored as Supabase secrets, never in the app.
- **DB migrations**: Supabase CLI migrations (`supabase/migrations/*.sql`) — enums, tables, RLS, RPCs, triggers all version-controlled; never hand-edit prod. RPCs/policies are code-reviewed.
- **Edge Functions**: in `supabase/functions/`, deployed via CLI; secrets via `supabase secrets set`.
- **Flutter builds**: Android App Bundle + iOS build; signing configs out of source.
- **CI** (GitHub Actions or similar): `flutter analyze`, `flutter test`, build check, migration lint on PR.
- **Release notes for stores**: declare data collection accurately (phone number + profile data; **no Aadhaar/document collection in v1**); complete iOS/Android accessibility & privacy questionnaires.

---

## 17. Phased Delivery Roadmap (build in this order)

Each milestone is independently shippable/testable and depends only on earlier ones — follow top to bottom.

**M0 — Foundations**
- Create Flutter project; add Riverpod, supabase_flutter, go_router, freezed, firebase. Set up `core/` (config, theme, router, error, accessibility helpers). Init dev/prod Supabase projects + CLI.

**M1 — DB schema, RLS, Auth**
- Migrations: enums, all tables, indexes, RLS policies, `assigned_counterpart_contacts` view, profile-creation trigger/RPC.
- Configure Supabase phone provider + SMS gateway. `AuthRepository` + **phone-OTP request/verify**, sign-out; splash/auth-resolver; complete-profile gate; role-gated router.

**M2 — Profiles & Registration**
- Requester & Volunteer profile creation/edit; **no Aadhaar capture**; availability toggle (`is_active`). Verification status surfaced (read-only) on volunteer profile.

**M3 — Request creation + Broadcast + FCM**
- New Request screen + `RequestRepository.create`; `broadcast_request` Edge Function; FCM token registration (`devices`); volunteer Available list (Realtime). Notifications wired.

**M4 — FCFS Acceptance**
- `accept_request` RPC (atomic UPDATE); volunteer Accept action; assignment push; contact exchange via view; OTP generated. Concurrency test proves single-winner.

**M5 — Trip start/complete + Billing**
- OTP display (requester) / entry (volunteer) → `start_trip`; `complete_trip` (duration + amount); status surfaced live on both sides.

**M6 — Payment (two-sided) + Ratings**
- `mark_paid` (requester) + `mark_received` (volunteer) RPCs + both UI actions; `payment_status` derivation + `payment_confirmed` push when both. Mutual Rating sheet → `submit_rating`; aggregates; request `closed`.

**M7 — Admin verification**
- Admin RPC `set_verification`; minimal admin web page (list pending volunteers, approve/reject + reason — **decision-only, no Aadhaar**); `verification_result` push. Enforce "approved-only can accept."

**M8 — Accessibility hardening, tests, release**
- Full TalkBack/VoiceOver pass on every screen; automated a11y checks; complete unit/widget/integration/backend test suites; crash reporting; store builds + privacy/a11y submissions.

---

## 18. Future Extensions (post-v1, no redesign needed)

- **Aadhaar verification (document capture)** — add a private Storage bucket + upload flow + admin signed-URL review; `volunteer_profiles` gains a document reference. Compliance review first; storage component already reserved.
- **Email+password alternate login** — add methods to `AuthRepository` + extend the Supabase impl; no domain/UI changes.
- **Geo-radius matching** — enable PostGIS; use existing `*_lat/*_lng` + `service_area`; filter `broadcast_request` & Available query by radius.
- **In-app payments / commission** — add a payment provider behind a `PaymentRepository`; `trips.payment_status` already models lifecycle.
- **Live GPS tracking** — new `trip_locations` table + Realtime; map UI.
- **In-app chat / report-user / blocklist** — safety features for trust.
- **Scaling** — Supabase plan upgrade, read replicas, partition `requests`/`trips` by date when volume grows; the layered architecture and server-side RPCs absorb this without client rewrites.

---

*End of design. Build by following Section 17; all decisions needed for one-shot execution are captured above.*
