# TravAcs — End-to-End Development Design (Firebase)

> **Status:** Approved design for v1 (initial release). **Backend: Firebase.**
> **Audience:** Engineering team building TravAcs one-shot, top-to-bottom.
> **Companion docs:** `appRequirements.md` (product vision & requirements), `EngPrinciples.md` (engineering standards).
> **History:** v1 was first designed on Supabase; we migrated to **Firebase** to remove backend friction — most importantly **phone-OTP for Indian (+91) numbers**, which Firebase Phone Auth delivers through Google's own infrastructure with **no DLT registration** required of us (Supabase needed a third-party SMS gateway + India DLT). The earlier Supabase implementation is preserved on the `master_old` git branch.
> **How to use this document:** Sections 1–16 are the *what & how*. Section 17 is the *build order* — follow it sequentially.

---

## 0. Locked Decisions (read first)

| # | Area | Decision | Why |
|---|------|----------|-----|
| 1 | **Mobile** | **Flutter** (Android + iOS, single codebase). | Required by constraints; strong a11y. |
| 2 | **Backend** | **Firebase** (Auth, Cloud Firestore, Cloud Functions, Storage, FCM, App Check). | One integrated platform; great Flutter SDKs; solves India OTP. |
| 3 | **Auth** | **Firebase Phone Auth** (SMS OTP). Wrapped behind an `AuthRepository` abstraction. | OTP "just works" for +91 via Google — **no SMS gateway, no DLT**. |
| 4 | **Database** | **Cloud Firestore** (native mode). | Real-time listeners + **atomic transactions** (needed for FCFS) + Security Rules. |
| 5 | **Accept (slot-filling FCFS)** | A request needs **N TravAcsers** (1 per 2 users). The **`acceptRequest` Cloud Function** runs a Firestore **transaction** per accept — claims a slot, creates a per-TravAcser assignment + contact pair + OTP, increments `acceptedCount`, flips to `assigned` when full. The transaction guarantees no over-subscription. | Strong consistency; per-TravAcser trips/OTP/payment. |
| 6 | **Server logic** | **Cloud Functions** only where a server is unavoidable: **FCM fan-out** to volunteers, **trip-OTP hashing/verify**, **admin custom claims**. Requires the **Blaze** plan. | Clients can't multicast push or mint admin claims. |
| 7 | **App architecture** | **Riverpod** (DI + state) + **layered** (data / domain / presentation) + **Repository pattern**. | SOLID, testable; lets the backend swap (as this migration proved). |
| 8 | **Matching** | **Region-scoped broadcast:** both sides pick a fixed **`serviceArea`** (Delhi NCR + states/UTs); a request is broadcast only to approved, active TravAcsers whose `serviceArea` **equals** the request's. FCFS decides. (Optional `geohash` later for finer geo-radius.) | Deterministic, no GPS; right scope for targeted FCM. |
| 9 | **Aadhaar / Verification** | **No Aadhaar data captured or stored in v1.** Volunteers verified **manually/out-of-band** by admin (sets `verificationStatus`). | Avoid PII/compliance burden now. |
| 10 | **Billing & Payment** | ₹135/hour, **pro-rated per minute**: `amount = round(durationMinutes / 60 * 135)`. External UPI with **two-sided confirmation** (requester marks **Paid**, volunteer marks **Received**; settled when both). | Matches requirements; mutual trust. |
| 11 | **Trip start** | **6-digit OTP** generated on assignment, stored **hashed** (via a Cloud Function), shown to the requester, entered + verified by the volunteer. | Proof both parties met. |
| 12 | **Plan/cost** | v1 **foundations (Auth + Firestore + profiles) run on the free Spark plan.** **Blaze** is needed once Cloud Functions ship (FCM fan-out, M3+). Phone Auth has a monthly free verification quota; budget a small per-SMS cost beyond it. | Keep cost minimal early. |

---

## 1. Introduction & Goals

### 1.1 Product summary
TravAcs connects **visually impaired users ("Requesters")** with **verified volunteers ("TravAcsers")** who provide short-duration, paid travel/mobility assistance (e.g., home → metro station). v1 prioritizes **accessibility, reliability, simplicity, and low cost**.

### 1.2 Success criteria (v1)
1. Register as Requester or Volunteer (phone-OTP).
2. Volunteer verified (admin-approved, manual).
3. Requester creates an assistance request.
4. A volunteer accepts (FCFS, transaction-guaranteed single winner).
5. Trip starts via OTP and is completed; duration & amount computed.
6. Payment coordinated externally (UPI), two-sided confirmation.
7. Both parties rate each other.
8. The entire Requester flow is fully usable with a screen reader.

### 1.3 In scope (v1)
Registration, profiles, request lifecycle, FCFS assignment, OTP trip start, completion + billing, external-payment confirmation, mutual ratings, push notifications, admin verification, accessibility.

### 1.4 Explicit non-goals (v1)
- ❌ In-app payments / wallet / commission.
- ❌ Real-time GPS live tracking on a map.
- ❌ Aadhaar capture/storage (manual verification for v1).
- ❌ Email/social login (phone+OTP only in v1).
- ❌ Geo-radius matching (broadcast-all for now; geo-ready docs).
- ❌ In-app chat (phone numbers shared on assignment).

### 1.5 Key constraints
Single codebase; minimal infra cost; <1000 users initially; production-grade quality; accessibility mandatory. Phone-OTP uses Firebase's free verification quota first, then a small per-SMS cost.

---

## 2. High-Level Architecture

```
┌─────────────────────────────┐        ┌────────────────────────────────────────────┐
│        Flutter App          │        │                  Firebase                    │
│  (Android / iOS)            │        │                                              │
│                             │        │  ┌──────────────┐   ┌──────────────────────┐ │
│  presentation (Riverpod)    │◄──SDK─►│  │ Firebase Auth│   │ Cloud Firestore       │ │
│  domain (use cases/models)  │        │  │ (Phone OTP)  │   │  profiles, requests,  │ │
│  data (repos + Firebase SDK)│        │  └──────────────┘   │  trips, ratings,      │ │
│                             │        │  ┌──────────────┐   │  devices              │ │
│  ┌───────────────────────┐  │        │  │ App Check    │   │  + Security Rules     │ │
│  │ FCM SDK (push tokens) │  │        │  └──────────────┘   └──────────────────────┘ │
│  └───────────┬───────────┘  │        │  ┌──────────────┐   ┌──────────────────────┐ │
└──────────────┼──────────────┘        │  │ Storage      │   │ Cloud Functions      │ │
               │                       │  │ (unused v1)  │   │ onRequestCreate→FCM, │ │
               │   push                │  └──────────────┘   │ startTrip(OTP),      │ │
               │                       │                     │ setVerification, ... │ │
        ┌──────▼───────┐               │                     └───────────┬──────────┘ │
        │     FCM      │◄──────────────────────────────────────────────┘            │
        └──────────────┘               └──────────────────────────────────────────────┘
                                  ┌──────────────────────────────┐
                                  │ Firebase Console + minimal   │
                                  │ admin (approve/reject)       │
                                  └──────────────────────────────┘
```

**Trust boundaries**
- The **Flutter client is untrusted**: it talks to Firestore directly, and **Security Rules** decide every read/write. The FCFS state transition is a client transaction whose validity is enforced by rules.
- **Privileged/server-only work** runs in **Cloud Functions** (Admin SDK, bypasses rules): FCM fan-out, trip-OTP hashing/verification, setting `admin`/verification, any cross-user writes.
- **Admin** identity = a Firebase Auth **custom claim** (`admin: true`), set only by a Cloud Function / Admin SDK.
- **App Check** attests that traffic comes from your genuine app, protecting Firestore/Functions from abuse.

---

## 3. Technology Stack & Rationale

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Mobile UI | Flutter 3.x | Single codebase, mature a11y. |
| State / DI | **Riverpod** | Compile-safe DI, testable. |
| Firebase core | `firebase_core` + **FlutterFire CLI** (`flutterfire configure` → `firebase_options.dart`) | Per-environment config. |
| Auth | `firebase_auth` (Phone) | OTP for +91 with no gateway/DLT. |
| Database | `cloud_firestore` | Real-time + transactions + rules. |
| Functions | `cloud_functions` (client) + **Cloud Functions for Firebase** (Node/TS, Admin SDK) | Server-only logic. |
| Push | `firebase_messaging` (FCM) | Native to Firebase. |
| Integrity | `firebase_app_check` | Anti-abuse attestation. |
| Storage | `firebase_storage` | Reserved; **unused in v1**. |
| Routing | `go_router` | Auth/role-gated navigation. |
| Models | `freezed` + `json_serializable` (+ Firestore converters) | Immutable, type-safe. |
| Tests | `flutter_test`, `mocktail`, `fake_cloud_firestore`, `firebase_auth_mocks` | Unit/widget/data tests without a live backend. |

---

## 4. Domain Model & Roles

### 4.1 Roles
- **Requester** — creates requests, starts/ends trips, rates, pays externally.
- **TravAcser (Volunteer)** — verified manually, accepts requests, runs the trip, confirms payment, rates.
- **Admin** — approves/rejects volunteer verification (Firebase `admin` custom claim).

Role is stored on the user's `profiles/{uid}` document (`role` field) and is the source of truth for Security Rules; admin is additionally a custom claim.

### 4.2 Request lifecycle (state machine)
```
 draft → broadcast → assigned → started → completed → closed
   │         │           │          │
   └─cancel─►cancelled (allowed only before 'started')
```
Transitions are enforced by **Security Rules** (allowed field/status deltas) and, for OTP/payment, by **Cloud Functions**.

### 4.3 Volunteer verification (state machine)
```
 pending → approved          (admin)
    └────→ rejected → (admin re-review) → pending
```
Manual/out-of-band in v1; **no Aadhaar captured**. Only `approved` volunteers can read `broadcast` requests or win an accept (enforced in rules).

---

## 5. Data Model (Cloud Firestore)

> Firestore is schemaless documents; this is the **enforced shape** (via Security Rules + app DTOs). Money is integer INR. Timestamps are Firestore `Timestamp`. IDs are auto-IDs unless noted. **No Aadhaar fields.**

### 5.1 Collections

**`profiles/{uid}`** (doc id = Firebase Auth uid)
```
role: 'requester' | 'volunteer'        // 'admin' lives in a custom claim
fullName: string
gender?: 'male'|'female'|'other'|'prefer_not_to_say'
dateOfBirth?: timestamp
phone?: string                          // from Auth
serviceArea: string                     // REQUIRED region (e.g. 'delhi_ncr');
                                        //   fixed `Region` enum, same list both sides
isActive: bool                          // volunteer availability
createdAt, updatedAt: timestamp
// requester-only:
homeLocationText?: string
// volunteer-only:
address?: string
verificationStatus?: 'pending'|'approved'|'rejected'
rejectionReason?: string
ratingAvg: number, ratingCount: int
```
> Role-specific fields live on the same doc (one read). Sub-objects could be used, but flat fields keep rules simple.

**`requests/{requestId}`**
```
requesterId: uid
volunteerId?: uid                       // null until assigned
status: 'draft'|'broadcast'|'assigned'|'started'|'completed'|'closed'|'cancelled'
scheduledDate: timestamp
startTime: string  (HH:mm)
expectedDurationMinutes: int
pickupText, destinationText: string
pickupGeo?, destGeo?: geopoint          // geo-ready
requirements?, instructions?: string
serviceArea: string                     // REQUIRED; copied from the requester's
                                        //   profile at creation; matching key
otpHash?: string                        // set by Cloud Function on assignment
contact: { requesterName, requesterPhone, volunteerName?, volunteerPhone? }  // filled on assignment
createdAt, updatedAt: timestamp
```
Composite indexes: `(status, createdAt)` for the volunteer "available" feed; `(requesterId, createdAt)`; `(volunteerId, status)`.

> **Slot-filling (M4+):** requests carry `acceptedCount` + `numTravAcsers`; each acceptance is a doc in **`requests/{id}/assignments/{volunteerId}`** (contact pair, denormalized request summary, and — from M5 — per-TravAcser trip fields: started/ended/duration/amount/paymentStatus). The per-TravAcser trip-start OTP plaintext lives in **`requests/{id}/secrets/{volunteerId}`**, readable only by the requester. This **replaces** the single `trips/{requestId}` doc below for the multi-TravAcser model.

**`trips/{requestId}`** (legacy single-TravAcser shape; superseded by per-assignment above)
```
requestId: string
startedAt?, endedAt?: timestamp
durationMinutes?: int
hourlyRateInr: int (=135 snapshot)
amountInr?: int
completedBy?: uid
paymentStatus: 'pending'|'awaiting_other'|'confirmed'
requesterPaidAt?, volunteerReceivedAt?: timestamp
createdAt, updatedAt: timestamp
```

**`ratings/{requestId}_{raterRole}`** (deterministic id ⇒ one rating per side)
```
requestId, raterId, rateeId: string
raterRole: 'requester'|'volunteer'
stars: 1..5
feedback?: string
createdAt: timestamp
```

**`devices/{uid}/tokens/{token}`** — FCM tokens (subcollection per user). `platform`, `updatedAt`.

### 5.2 Security Rules (the heart of authz — replaces RLS)
Principles (full rules authored in M1):
- **profiles:** a user can `read/write` only `profiles/{uid == request.auth.uid}`. **`role` is immutable after creation; `verificationStatus`/`rejectionReason`/`ratingAvg`/`ratingCount` are NOT client-writable** (only Cloud Functions/admin). Counterpart name+phone are exposed via the request's `contact` map (written server-side on assignment), so no broad profile reads.
- **requests:** `create` allowed when `requesterId == uid` and `status in ('draft','broadcast')`. `read` allowed to the owner, the assigned volunteer, or — when `status=='broadcast'` — an **approved, active volunteer** (rules `get()` the caller's profile). The **accept transition** is the only client update on someone else's-visible request: allowed iff `resource.status=='broadcast' && resource.volunteerId==null && request.status=='assigned' && request.volunteerId==uid && isApprovedVolunteer()` and no other protected field changes. All other status changes go through Cloud Functions.
- **trips / ratings:** read if a party to the request; writes via Cloud Functions (trips) or constrained client writes (ratings: id must equal `{requestId}_{role}`, `raterId==uid`).
- **devices:** read/write own subtree only.
- Helper functions in rules: `isSignedIn()`, `myProfile()`, `isApprovedVolunteer()`, `isAdmin()` (`request.auth.token.admin == true`).

> Firestore transactions + these rules give the FCFS guarantee: two volunteers accepting concurrently both run a transaction; the first commits (`broadcast→assigned`), the second's transaction re-reads the now-`assigned` doc and its rule check fails / it aborts.

---

## 6. Server-Side Logic (Cloud Functions for Firebase)

Node/TypeScript, Admin SDK (bypasses rules; re-checks auth internally). Callable or Firestore-triggered. Shared result `{ ok, code, data? }`.

- **`onRequestCreated` (Firestore trigger, `requests/{id}` onCreate)** — when `status=='broadcast'`, **fan out FCM** to approved+active TravAcsers **whose `serviceCity` == the request's** (region-scoped). It does **not** mint the trip OTP — that happens at **assignment** (M4/M5), tied to the specific volunteer.
- **`acceptRequest(requestId)` (callable, Admin SDK) — slot-filling** — verifies the caller is an approved+active TravAcser in the request's city, then runs a **transaction**: rejects if the request isn't `broadcast`, the caller already accepted, or all slots are full; otherwise creates `requests/{id}/assignments/{uid}` (contact pair + denormalized summary), writes the per-TravAcser OTP plaintext to `requests/{id}/secrets/{uid}` (requester-readable only), increments `acceptedCount`, and sets `status='assigned'` when `acceptedCount==numTravAcsers`. Pushes the requester. Returns `ALREADY_TAKEN`/`ALREADY_ACCEPTED`/`WRONG_CITY`/`NOT_APPROVED` on failure. The transaction's count read+write prevents over-subscription.
- **`startTrip(requestId, otp)` (callable, per assignment)** — caller is the assignment owner. Transaction: assignment `tripStatus=='assigned'`; verify `otp` against the plaintext in `secrets/{uid}` (server reads it; the TravAcser cannot); on mismatch increment `otpAttempts` (lock at 5 → `RATE_LIMITED`); on match set `tripStatus='started'`, `startedAt`, and **delete the secret** (consumed). Push the requester.
- **`completeTrip(requestId, volunteerId)` (callable, per assignment)** — caller is that TravAcser **or** the requester; assignment `tripStatus=='started'`. Compute `durationMinutes = max(1, round((now−startedAt)/60000))`, `amountInr = round(durationMinutes/60 × 135)`; set `tripStatus='completed'`, `endedAt`, `durationMinutes`, `amountInr`, `paymentStatus='pending'`. When **all** assignments are completed, set `request.status='completed'`. Push both.
- **`markPaid(requestId, volunteerId)` / `markReceived(requestId)` (callable, per assignment)** — role-locked (requester / that TravAcser), idempotent; assignment must be `completed`; set `requesterPaidAt`/`travAcserReceivedAt`; recompute `paymentStatus` (`confirmed` when both set, else `awaiting_other`); push the counterpart.
- **`submitRating(requestId, volunteerId, stars, feedback?)` (callable, per assignment)** — caller = requester or that TravAcser → derives rater/ratee; assignment `completed`; rejects a second rating from the same side. Transaction writes the rating onto the **assignment** (`requester*`/`volunteer*RatingStars/Feedback`) and updates the ratee's **`profiles/{uid}.ratingAvg`/`ratingCount`**. No separate `ratings` collection in v1 (ratings/payment live on the assignment).
- **`setVerification(uid, decision, reason?)` (callable, admin-only)** — set volunteer `verificationStatus`; push `verificationResult`.
- **`setAdminClaim(uid)` (one-off, Admin SDK script)** — bootstrap the first admin.

Error `code`s: `NOT_AUTHENTICATED`, `NOT_APPROVED`, `FORBIDDEN`, `ALREADY_TAKEN`, `INVALID_STATE`, `OTP_INVALID`, `RATE_LIMITED`, `NOT_FOUND`, `OK`.

---

## 7. Authentication & Authorization

- **Firebase Phone Auth.** Flow: `verifyPhoneNumber(phone)` → Firebase sends SMS (handles +91 via Google, **no DLT**) → user enters code → `signInWithCredential(PhoneAuthProvider.credential(verificationId, smsCode))` → session. On Android, **SHA-1/SHA-256** must be registered in the Firebase project and **Play Integrity/App Check** enabled (Firebase auto-uses reCAPTCHA fallback). On iOS, APNs + URL scheme are configured by FlutterFire.
- **First sign-in vs login** is unified; if `profiles/{uid}` doesn't exist post-auth, route to **complete-profile** (role + fields) which creates the doc.
- **`AuthRepository`** interface: `requestOtp(phone) → verificationId`, `verifyOtp(verificationId, code)`, `signOut`, `currentUser`, `authStateChanges`. (Email/social can be added later behind the same interface.)
- **Authorization** = Security Rules + custom claims (`admin`). Role checks in rules `get()` the profile doc.
- **App Check** enforced on Firestore + Functions in production.

---

## 8. Notifications (FCM)

- Native to Firebase. Token lifecycle: on login & refresh, write `devices/{uid}/tokens/{token}`; delete on logout.
- **Message types** (`data.type`): `new_request`, `assignment`, `trip_started`, `trip_completed`, `payment_marked`, `payment_confirmed`, `rating_received`, `verification_result`.
- **Fan-out** is server-side in `onRequestCreated` and the payment/assignment functions (Admin SDK `sendEachForMulticast`). New-request fan-out is **filtered to the request's `serviceArea`** so only same-region TravAcsers are notified.
- **In-app realtime** uses **Firestore listeners** (snapshots) on the user's own requests/trips — the source of truth for live UI; FCM is the wake/alert.

---

## 9. Flutter App Architecture

```
lib/
  main.dart                      # Firebase.initializeApp(options) + ProviderScope
  app.dart
  firebase_options.dart          # generated by `flutterfire configure`
  core/{config,error,router,theme,utils,accessibility}
  data/
    models/                      # freezed DTOs + Firestore (from/to)Map converters
    datasources/                 # thin wrappers over FirebaseAuth / FirebaseFirestore / Functions
    repositories/                # FirebaseAuthRepository, FirestoreProfileRepository, ...
  domain/{entities,repositories,usecases}
  presentation/{providers,features/{auth,profile,shell,...}}
```
- **domain** stays framework-free (entities, repository interfaces, use cases) — unchanged by the backend swap.
- **data** implements the interfaces against Firebase; maps Firestore docs ↔ entities; converts `FirebaseAuthException`/`FirebaseException` → `Failure`.
- **presentation** Riverpod controllers call use cases; widgets render `AsyncValue`.
- Config: `firebase_options.dart` per environment (dev/prod via flavors or separate apps); `hourlyRateInr=135` constant mirrors server.

---

## 10. App Navigation & Screens

WhatsApp/Instagram-style **bottom `NavigationBar` over `IndexedStack`**, role-specific tabs. (Unchanged from product intent.)
- **Requester:** New Request · My Requests (live Firestore stream: status, contact, OTP to share, Complete, **Mark Paid**, Rate) · History · Profile.
- **Volunteer:** Available (live `status==broadcast` stream; **Accept** via transaction) · My Trips (Enter OTP→Start, Complete, **Mark Received**, Rate) · Earnings · Profile (+ verification status, availability toggle).
Requirement→screen traceability identical to product steps 1–9; step 3 broadcast now = `onRequestCreated` Cloud Function → FCM.

---

## 11. Accessibility Design (first-class) — M9
Mandatory and now implemented:
- **Semantic labels & roles** on every interactive control; form fields use `labelText` (100% — no hint-only fields). Section titles carry `Semantics(header: true)` for heading-by-heading navigation.
- **Announcements** (`A11y.announce` → `SemanticsService.announce`) on every status change, success and error — including ones that are otherwise silent to a screen reader: the **OTP resend** button becoming enabled ("You can resend the code now.") and **bottom-tab changes** ("<Tab> tab"). The login/trip OTP is read **digit-by-digit** (`A11y.spellDigits`).
- **Never colour-only:** status is always paired with text **and** an icon (e.g. the request `_StatusChip` and the verification card), and exposed to screen readers via an explicit `Semantics(label: 'Status: …')`.
- **Coherent traversal:** reusable cards wrap their informational block in `MergeSemantics` so a swipe lands on one summary node (status + route + time), while action buttons stay outside the merge and keep their own button semantics; decorative leading icons are `ExcludeSemantics`.
- **Touch & text sizing:** ≥48dp targets (`MaterialTapTargetSize.padded`); OS large-text is respected but **clamped to `textScaler ∈ [1.0, 1.8]`** in `app.dart` so fixed layouts never clip or overlap.
- **Dialogs:** titled `AlertDialog`s with `autofocus` on the first field; focus returns to the trigger on dismiss.
- **Verification:** automated `meetsGuideline` tests (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`) + semantic-label assertions in `test/accessibility_test.dart`, plus a manual TalkBack/VoiceOver pass of the full request→accept→trip→pay→rate flow. The User (blind) flow is screen-reader-complete.

---

## 12. Admin Panel
- **Firebase Console** for raw data inspection/support.
- An **in-app admin screen** (same Flutter app): a user with the **`admin` custom claim** logs in via phone OTP and is **routed to `/admin`** (admin check precedes the requester/volunteer profile routing, so admins need no role profile). The screen lists `profiles` where `role=='volunteer' && verificationStatus=='pending'` (name/phone/region/address — **no Aadhaar** in v1) and **approves/rejects** via the admin-only **`setVerification(uid, decision, reason?)`** callable. Builds to Flutter web too if a standalone console is later wanted.
- **First admin bootstrapped** with `make_admin.js` (sets the `admin` custom claim by phone via the Identity Toolkit Admin API); the admin then re-logs-in. Identity verification stays out-of-band — this is the decision UI only.

---

## 13. Security & Privacy
- **Security Rules on every collection** (default-deny); transitions/protected fields locked down (§5.2).
- **Cloud Functions** (Admin SDK) for all privileged writes; clients can't set `role`, `verificationStatus`, `volunteerId` (except the guarded accept), `amountInr`, `paymentStatus`, or `otpHash`.
- **App Check** on Firestore + Functions; **no Aadhaar / minimal PII**; counterpart contact shared only via the request `contact` map after assignment.
- **Trip OTP** hashed server-side (bcrypt), never sent to the volunteer (distinct from the Firebase login SMS OTP).
- **Secrets** (FCM/admin) live in Cloud Functions config; the app ships only the public Firebase config (safe by design, protected by rules + App Check).
- **Safety for vulnerable users:** only verified volunteers can accept; mutual ratings; report/block hook for later.

---

## 14. Error Handling, Logging & Monitoring (M8)
**Invariant:** users **never** see a raw failure, error code, or stack trace. Every error the user encounters is a calm, specific, screen-reader-friendly sentence. Raw detail (`code`, original message, `toString()`) is carried **only** in a non-user-facing `debugDetail` field and logged to Crashlytics — never rendered.

**Failure taxonomy** (`core/error/failure.dart`) — sealed `Failure { message, code?, debugDetail?, isRetryable }` with granular subtypes, each with a friendly default `message`:
- `NetworkFailure` (offline/timeout — retryable) · `AuthFailure` (auth/session/OTP) · `PermissionFailure` (not authorized) · `NotFoundFailure` · `ConflictFailure` (already-exists / slot taken / already-rated) · `RateLimitFailure` (too-many — retryable) · `ValidationFailure` (invalid input) · `UnavailableFailure` (service down / deadline — retryable) · `ServerFailure` (generic server/internal) · `UnexpectedFailure` (unknown — generic message; raw only in `debugDetail`).

**Comprehensive mapper** (`core/error/firebase_error_mapper.dart`) — `mapFirebaseError(Object, [StackTrace?])` converts **any** caught error to a `Failure` and reports it once (non-fatal) to Crashlytics. Order matters: `FirebaseFunctionsException` is checked **before** `FirebaseException` (it is a subclass).

| Source | Code | → Failure |
|---|---|---|
| Callable (`FirebaseFunctionsException`) | `unauthenticated` / `permission-denied` / `not-found` / `already-exists` / `resource-exhausted` / `invalid-argument` / `unavailable`·`deadline-exceeded` / `internal`·`unknown` | Auth / Permission / NotFound / Conflict / RateLimit / Validation / Unavailable / Server |
| Callable | `failed-precondition` | uses the function's **developer-set** message (ours are user-facing, e.g. *"All TravAcser slots are filled."*) |
| `FirebaseAuthException` | `operation-not-allowed`, `app-not-authorized`, `missing-client-identifier`, `captcha-check-failed`, `quota-exceeded`, `user-disabled`, `invalid-verification-code`, … | mapped to friendly Auth/Validation messages; default → generic `AuthFailure` |
| `FirebaseException` (Firestore/Storage) | `permission-denied` / `unavailable`·`deadline-exceeded` / `not-found` / `resource-exhausted` / `failed-precondition`(e.g. missing index) | Permission / Unavailable / NotFound / RateLimit / Server; default → `ServerFailure` |
| `SocketException` / `TimeoutException` / `HandshakeException` | — | `NetworkFailure` |
| anything else | — | `UnexpectedFailure(debugDetail: error.toString())` |

**Stream-error mapping** (`core/error/stream_error.dart`) — `Stream<T>.mapErrorToFailure()` is applied to every Firestore stream (`watchMyRequests`, `watchAvailableRequests`, `watchMyAssignments`, `watchRequestAssignments`, `watchShareOtp`, `watchPendingVolunteers`) so a `StreamProvider`'s `.error` is **always** a `Failure`.

**Global boundary** (`main.dart` + `core/error/`) — after Firebase init: `FlutterError.onError` and `PlatformDispatcher.instance.onError` route to `ErrorReporter` (Crashlytics, guarded — no-op in tests / when unavailable). In release, `ErrorWidget.builder` renders a friendly `ErrorFallback` widget instead of Flutter's red/grey stack-trace screen (the red box is kept in debug).

**UI surfacing** — screens render errors via `failureMessage(Object?)` → `e is Failure ? e.message : 'Something went wrong. Please try again.'`; both the snackbar and `A11y.announce` use that friendly text. No screen displays `code` or `toString()`.

**Tests** — `test/error_mapper_test.dart` asserts each representative input maps to the expected subtype and that `message` contains **no** raw text/code tokens (locks in the no-leak guarantee). Full suite is M10.

Graceful degradation remains: idempotent callables so retries are safe; offline reads via Firestore's local cache; **Cloud Functions logs** + **Firestore usage** in the console.

---

Phased: **M10a** = pure-Dart suite (`flutter test`, no emulator); **M10b** = emulator-backed rules + functions tests; **M10c** = CI.

- **M10a — Unit/data (done):** runs entirely offline via **`fake_cloud_firestore`** + **`firebase_auth_mocks`** + **`mocktail`**.
  - `test/domain_test.dart` — billing math (`computeEstimate`), `suggestedTravAcsers`, slot/duration getters, every enum/`Region`/`City` `fromWire` round-trip, `Profile.copyWith`, `Assignment` rating flags.
  - `test/repository_test.dart` — profile upsert keeps immutable fields (client can't flip `role`/`verificationStatus`), request create writes the right estimate/status, the watch-queries filter by owner/city/status, and callable-backed methods return a `Failure` instead of throwing.
  - `test/provider_test.dart` — `availableRequestsProvider` filtering (city + approval + already-accepted exclusion) and `myProfileProvider` surfacing a `Failure` as `AsyncError`.
  - `test/widget_flow_test.dart` — rating-sheet gating + `(stars, feedback)` return; OTP-field validation + resend cooldown.
  - `test/error_mapper_test.dart` (M8) + `test/accessibility_test.dart` (M9) round out the offline suite.
- **M10b — Rules tests:** `@firebase/rules-unit-testing` (emulator) — each role can/can't do the right thing; protected-field writes rejected; OTP-secret requester-only.
- **M10b — Functions tests:** emulator + unit tests for FCFS `acceptRequest`, `startTrip` (OTP + rate-limit), `completeTrip` billing, two-sided payment, `setVerification` admin gate.
- **M10c — CI:** GitHub Actions runs `flutter test` on every push (+ an optional emulator job).
- **Accessibility (M9):** `test/accessibility_test.dart` — `meetsGuideline` (tap-target, labeled-tap, text-contrast) + semantic-label assertions; plus a manual TalkBack/VoiceOver pass.

---

## 16. Environments, Config & CI/CD
- **Two Firebase projects:** `travacs-dev` and `travacs-prod` (FlutterFire flavors / separate `firebase_options`).
- **Firestore Rules + indexes** version-controlled in `firebase/` (`firestore.rules`, `firestore.indexes.json`); deploy via `firebase deploy --only firestore`.
- **Cloud Functions** in `firebase/functions/` (TypeScript); deploy via `firebase deploy --only functions` (**Blaze plan required**).
- **Emulator Suite** for local dev/test (Auth, Firestore, Functions).
- **Android:** register **SHA-1/SHA-256** per environment (required for Phone Auth/App Check); `google-services.json`. **iOS:** `GoogleService-Info.plist` + APNs key.
- **CI:** `flutter analyze` + `flutter test` + rules/functions emulator tests on PR.
- **Store privacy:** declares phone number + profile data; **no Aadhaar** in v1.

---

## 17. Phased Delivery Roadmap (Firebase)

**M0 — Foundations**
- Reuse the Flutter app structure (presentation/domain unchanged). Swap deps to Firebase. Create `travacs-dev` Firebase project; `flutterfire configure` → `firebase_options.dart`; register Android SHA-1; enable Phone Auth. `core/` (config, theme, router, error, a11y) reused as-is.

**M1 — Firestore model, Rules, Auth**
- `firebase/firestore.rules` + `firestore.indexes.json` (collections + helpers §5). Enable **App Check**.
- `AuthRepository` (phone OTP via `firebase_auth`); splash/auth-resolver; complete-profile gate; role-gated router. (Reuse existing screens; swap the repo impls.)

**M2 — Profiles & Registration + Shell**
- `FirestoreProfileRepository` (`profiles/{uid}` read/write via Rules; availability toggle). Reuse complete-profile screen, profile tab, and the role-based tab shell. Verification status surfaced.

**M3 — Requests + Broadcast + FCM**
- New Request → `requests` create; `onRequestCreated` Cloud Function (OTP hash + FCM fan-out); volunteer "Available" live stream; FCM token registration. **(Blaze plan on.)**

**M4 — FCFS Accept**
- Client **Firestore transaction** `broadcast→assigned` + rules; assignment push; `contact` map populated. Concurrency test (rules + emulator) proves single-winner.

**M5 — Trip OTP/Start/Complete + Billing**
- `startTrip` (OTP verify) + `completeTrip` (duration + amount) callables; live status on both sides.

**M6 — Two-sided Payment + Ratings**
- `markPaid`/`markReceived` callables + UI; `submitRating` + aggregates; request `closed`.

**M7 — Admin verification**
- `setVerification` (admin claim) + minimal admin web; `verificationResult` push; "approved-only can accept" enforced in rules.

**M8 — Hardening, tests, release**
- Full TalkBack/VoiceOver pass; rules/functions/widget/integration tests on the Emulator Suite; Crashlytics; store builds.

---

## 18. Future Extensions (no redesign needed)
- **Email/social login** — add to `AuthRepository` + new impl.
- **Geo-radius matching** — `geohash` queries (e.g. `geoflutterfire`) over existing geo fields.
- **In-app payments / commission** — `PaymentRepository`; `paymentStatus` already models lifecycle.
- **Live GPS tracking** — `trips/{id}/locations` subcollection + listeners.
- **Aadhaar verification** — Firebase Storage upload + signed access + admin review (Storage already reserved).
- **Scale** — Firestore scales horizontally; add composite indexes and shard hot counters as needed.

---

*End of design. Build by following Section 17; the layered architecture means the Supabase→Firebase swap is concentrated in the `data/` layer + backend, with `domain/` and most of `presentation/` reused. The prior Supabase design/implementation is preserved on `master_old`.*
