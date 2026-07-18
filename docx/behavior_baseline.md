# TravAcs — Behavior Baseline (regression-safety reference)

> **Why this file exists.** This is a *complete, code-verified* snapshot of how the app behaves
> **today**, captured before an enhancement batch so that new work can be checked against it and does
> not silently break existing behavior. It is descriptive (what the code does now), not aspirational.
> When you change behavior intentionally, update the matching section here in the same PR.
>
> Companion docs: [`AGENTS.md`](../AGENTS.md) (setup/commands/invariants),
> [`docx/design_travacs.md`](design_travacs.md) (deep design). Where those disagree with the code,
> **the code — and this file — win.**
>
> Verified against the tree at the time of writing by reading every Cloud Function, the Security
> Rules, indexes, the full domain/data/provider/controller layer, and every screen.

---

## 0. How to use this for regressions
Before merging an enhancement, walk the **Invariants checklist** (§18) and the state machine (§10).
For any file you touched, re-read its subsection here and confirm the listed conditions still hold.
Run the quality gates (`flutter analyze`, `flutter test`, the two emulator suites) — §17 maps tests to
behavior so you can tell *which* behavior a red test protects.

---

## 1. What the app is
Accessibility-first mobile app pairing **visually-impaired Users** ("requester") with verified
**TravAcsers** ("volunteer") for **paid in-person travel assistance**. Flutter (Dart) client +
Firebase backend (Phone-OTP Auth, Firestore, Cloud Functions, FCM, Crashlytics). Project
`travacs-dev`; callables in `asia-south2`, scheduled functions in `asia-south1`.

**Pricing (current):** service charge **₹140/hr billed in 30-min blocks rounded UP** (`70 ×
ceil(minutes/30)`) **+ a flat ₹100 travel cost once per trip** (not per TravAcser). See §9.

### Roles & terminology (wire value vs label)
`UserRole` wire values stay `requester`/`volunteer`/`admin`; **user-facing labels are
"User"/"TravAcser"/"Admin"** (`enums.dart`). One TravAcser assists up to 2 travellers, so a request
suggests `(travellers+1)~/2` TravAcsers.

---

## 2. Architecture
Layered Clean-ish: `presentation → domain ← data`.
- **domain/** — pure Dart: entities + repository **interfaces** (no Firebase).
- **data/repositories/** — Firebase implementations.
- **presentation/** — Riverpod providers + `features/<feature>/…_controller.dart`; depends on interfaces.

**Result type:** repositories return `FutureResult<T> = Future<Either<Failure, T>>` (fpdart).
`success(v)`/`failure(f)` helpers in `core/error/result.dart`. UI/controllers `.match`/`.fold`; they
**never** `try/catch` Firebase directly — the repo maps errors via `mapFirebaseError` (§16).

**State:** Riverpod 3. `Provider`s wire repos; `StreamProvider`/`FutureProvider` expose live data;
`Notifier`-based `*_controller.dart` hold `AsyncValue<void>` and drive actions. Every controller
action sets `AsyncLoading()` → then `AsyncData(null)` on success / `AsyncError(failure)` on failure.

---

## 3. App bootstrap & global error boundary (`main.dart`, `app.dart`, `firebase_init.dart`)
1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `await FirebaseBootstrap.initialize()` (= `Firebase.initializeApp(options: DefaultFirebaseOptions
   .currentPlatform)`) **before** `runApp`. On success, registers
   `FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler)` (currently a no-op VM
   entry point). On throw, swallows and sets `firebaseReady = false`.
3. Global handlers:
   - `FlutterError.onError` → `ErrorReporter.reportFatal(..., fatal:false)`, and `presentError` **only
     in debug**.
   - `PlatformDispatcher.instance.onError` → `ErrorReporter.reportFatal(error, stack)`, returns `true`.
   - **release-only** `ErrorWidget.builder` → `ErrorFallback` (calm "Something went wrong" screen).
4. `runApp(ProviderScope(overrides: firebaseReadyProvider = result, child: TravAcsApp))`.

`app.dart`: if `firebaseReadyProvider == false` → `_NotConfiguredApp` (tells you to run `flutterfire
configure`). Otherwise `MaterialApp.router` with `AppTheme.light()/dark()`, `routerProvider`, and a
**text-scale clamp of `[1.0, 1.8]`** in `builder` (accessibility invariant).

---

## 4. Routing & the redirect gate (`core/router/app_router.dart`)
`GoRouter` with `initialLocation:'/splash'`, refreshed by a `_RouterNotifier` that listens to
`authStateChangesProvider`, `isAdminProvider`, `myProfileProvider`.

Routes: `/splash`, `/auth/phone`, `/auth/otp?phone=…`, `/complete-profile`, `/home` (role shell),
`/admin`.

**Redirect logic (exact):**
- Not signed in → `/auth/phone` (stay if already under `/auth`).
- Signed in, `isAdminProvider`:
  - loading → `/splash`
  - data `isAdmin == true` → `/admin` (skips the profile gate)
  - data `false` or error → `_profileRedirect`:
    - `myProfileProvider` loading/error → `/splash`
    - data `profile == null` → `/complete-profile`
    - data non-null and currently in auth/splash/complete-profile/admin → `/home`
    - else null (stay).

---

## 5. Firestore data model (collections & key fields)
| Path | Written by | Key fields |
|---|---|---|
| `profiles/{uid}` | client (editable) + functions (protected) | `role`, `fullName`, `gender?`, `dateOfBirth?`, `phone?`, `isActive`, `serviceArea` (state), `serviceCity` (matching key), `ratingAvg`, `ratingCount`; **volunteer:** `address?`, `verificationStatus`, `verifiedBy?`, `verifiedAt?`, `rejectionReason?`; **requester:** `homeLocationText?` |
| `requests/{id}` | client `create`; requester may only `cancel`; all else functions | `requesterId`, `requesterName?`, `volunteerId`(null), `status`, `serviceArea`, `serviceCity`, `acceptedCount`, `numTravellers`, `numTravAcsers`, `genderPreference`, `requesterGender?`, `genderRestricted`, `genderWidened`, `genderWidenAt?`, `scheduledDate`, `startTime`, `scheduledStartAt`, `expectedDurationMinutes`, `meetingPoint`, `destination`, `purpose?`, `specialNote?`, `estimatedAmountInr`, `travelCostCharged?`, `noTravAcserNotifiedAt?`, `cancelReason?`, `createdAt`, `updatedAt` |
| `requests/{id}/assignments/{volunteerId}` | **functions only** | contact pair (`volunteerId/Name/Phone`, `requesterId/Name/Phone`), denormalized summary (`scheduledDate`, `startTime`, `scheduledStartAt`, `expectedDurationMinutes`, `meetingPoint`, `destination`, `genderPreference`, `numTravellers`, `amountInrEstimate`), `tripStatus` (assigned/started/completed/closed/cancelled), `acceptedAt`, `startedAt`, `otpStartedAt`, `endedAt`, `durationMinutes`, `serviceChargeInr`, `travelCostInr`, `amountInr`, `paymentStatus`, `requesterPaidAt`, `travAcserReceivedAt`, `razorpayOrderId`, `razorpayKeyId`, `razorpayPaymentId`, `rescheduleStatus`, `rescheduleDeadlineAt`, ratings (`requesterRatingStars/Feedback`, `volunteerRatingStars/Feedback`) |
| `devices/{uid}/tokens/{token}` | client (self) | `platform`, `updatedAt` (FCM tokens) |
| `tripLogs/{id}` | functions only (`logManualTrip`) | admin telemetry (manual + future app trips) |
| `trips/{id}`, `ratings/{id}` | functions only | rules present; ratings actually live on the assignment |

> **No SMS trip-start OTP / `secrets` subcollection.** Trip start uses a deterministic **offline
> start-code** computed identically on both clients (§8). The doc `status` does **not** flip to
> `started` on trip start — only the *assignment* `tripStatus` does (see §10, critical).

---

## 6. Domain entities & enums (`domain/entities/`)
- **`Request`** — request fields above + **static billing helpers** (source of truth mirrored on the
  server): `billingBlocks(min)=ceil(min/30)` (min 1), `billableHours(min)=blocks/2`,
  `serviceCharge(min)=70×blocks`, `computeEstimate(min,n)=serviceCharge(min)×n+100`,
  `suggestedTravAcsers(t)=(t+1)~/2`. Getters: `slotsRemaining=(numTravAcsers-acceptedCount).clamp`,
  `isFull`, `durationHours`.
- **`Assignment`** — one TravAcser's trip slice. Getters: `ratedByRequester/Volunteer`,
  `needsRescheduleConfirm = rescheduleStatus=='pending'`, `effectiveStartAt = scheduledStartAt ??
  combineDateAndTime(...)`, `startOtp = tripStartOtp(...)` (§8), `isInProgress(now)=tripStatus==started`,
  `isActive=tripStatus.isActive`, `amountBreakdown` ("₹140/hr × H hr" + " + ₹100 travel" when
  `travelCostInr>0`). (`awaitingStart(now)` is used in the requester detail tile.)
- **`Profile`/`RequesterProfile`/`VolunteerProfile`/`MyProfile`** — `MyProfile.profile` + role row;
  `VolunteerProfile.isApproved = verificationStatus==approved`; `Profile.hasServiceArea = state&&city`.
- **`PendingVolunteer`**, **`City`** (curated list; matching key is city `wireValue`),
  **`RazorpayOrder`** (orderId, keyId, amountPaise, amountInr, currency).

**Enums (wire → label):**
- `UserRole`: requester/volunteer/admin → **User/TravAcser/Admin**.
- `Gender`: male/female/other/prefer_not_to_say.
- `GenderPreference`: `strict_same_gender` ("Strictly same gender"), `prefer_same_gender`,
  `any_gender`. `fromWire` defaults to `any_gender`.
- `VerificationStatus`: pending/approved/rejected.
- `RequestStatus`: draft/broadcast("Open")/assigned/started/completed/closed/cancelled;
  `isOpen=broadcast`, `isCancellable=draft||broadcast`.
- `TripStatus`: assigned("Scheduled")/started("In progress")/completed/closed/cancelled;
  `isActive=assigned||started`, `isTerminal=!isActive`; `fromWire` defaults to `assigned`.
- `PaymentStatus`: pending/awaiting_other/confirmed.
- `Region`: Delhi NCR (first) + all states/UTs.

---

## 7. Providers & controllers
### Read providers
| Provider | Type | Exposes |
|---|---|---|
| `firebaseReadyProvider` | Provider<bool> | init success (overridden in main) |
| `clockProvider` | StreamProvider<DateTime> | ticks **every 30s** so time-derived UI refreshes |
| `firebaseAuthProvider`/`firestoreProvider` | Provider | SDK singletons (overridable in tests) |
| `authStateChangesProvider` | StreamProvider<String?> | current uid (null = signed out) |
| `isAdminProvider` | FutureProvider<bool> | admin custom-claim |
| `myProfileProvider` | FutureProvider<MyProfile?> | null = registration incomplete; rethrows failure |
| `myRequestsProvider` | StreamProvider | requester's own requests (watches auth) |
| `myAssignmentsProvider` | StreamProvider | TravAcser's assignments via `collectionGroup('assignments')` where `volunteerId==uid` |
| `availableRequestsProvider` | StreamProvider | open requests in city, filtered (see below) |
| `requestAssignmentsProvider` | StreamProvider.family<_,requestId> | assignments of one request (requester view) |
| `activeTripsProvider` | StreamProvider | admin: all broadcast/assigned/started, ordered by `scheduledStartAt` |
| `pendingVolunteersProvider` | StreamProvider | admin: volunteers awaiting verification |
| `functionsProvider` | Provider | `FirebaseFunctions.instanceFor(region:'asia-south2')` |
| `shellTabIndexProvider` | NotifierProvider<int> | selected shell tab; `requesterMyRequestsTabIndex=1` |

**`availableRequestsProvider` filter (exact):** empty unless approved + city set. Then it hides a
request `r` unless **all** hold: `!acceptedIds.contains(r.id)` (only *active* own assignments hide it),
`r.scheduledStartAt.isAfter(now)` (past-start requests are dropped — server auto-cancels them), and
`(!r.genderRestricted || r.genderWidened || r.requesterGender == myGender)`. Watches `clockProvider`.

### Controllers (actions)
- `authControllerProvider`: `requestOtp(phone)` (stores `_verificationId`+phone), `verifyOtp(code)`
  (errors "Please request a new code." if no verificationId), `signOut()` (clears state).
- `profileControllerProvider`: `save(...)`, `setServiceArea(...)`, `setAvailability(...)` — each
  invalidates `myProfileProvider` on success (so the router advances).
- `requestControllerProvider`: `create` (returns new id/null), `cancel`, `accept`, `reschedule`,
  `cancelTrip`, `respondReschedule`, `completeTrip`, `startTrip`, `markPaid`, `createRazorpayOrder`,
  `verifyRazorpayPayment`, `markReceived`, `submitRating`.
- `adminControllerProvider`: `approve(uid)`, `reject(uid,reason)`, `logManualTrip(...)`.

Repository→callable mapping (`FirestoreRequestRepository`): `acceptRequest`, `startTrip`,
`completeTrip`, `rescheduleTrip`, `respondReschedule`, `cancelTrip`, `markPaid`, `markReceived`,
`submitRating`, `createRazorpayOrder`, `verifyRazorpayPayment` are all Cloud Functions callables.
**`createRequest` and `cancelRequest` write Firestore directly** (guarded by Rules, §11).

---

## 8. Deterministic offline trip start-code (`core/util/trip_otp.dart`)
`tripStartOtp({userPhone, travAcserPhone, scheduledStartAt})`:
- Normalize each phone: strip non-digits; if >10 digits keep **last 10**; null → "".
- Material = `userPhone|travAcserPhone|scheduledStartAt.millisecondsSinceEpoch`.
- `HMAC-SHA256(key = utf8(AppConstants.tripOtpSalt='travacs-trip-otp-v1'), material)`.
- RFC-4226-style dynamic truncation → 31-bit int → `mod 10^4` → left-pad to **4 digits**.
- **Because `scheduledStartAt` is an input, rescheduling changes the code.** Computed identically on
  both devices → no server round-trip, no SMS. The User reads it aloud; the TravAcser types it; the
  match is validated **client-side** and only then `startTrip` records the flip.

`combineDateAndTime(date, "HH:mm")` → local `DateTime` (bad input falls back to 0/midnight).
`formatTime12h("14:30")` → "2:30 PM" (invalid input returned unchanged).

---

## 9. Billing / pricing model (client + server must match)
- Constants (`constants.dart`): `hourlyRateInr=140`, `billingBlockMinutes=30`, `travelCostInr=100`,
  `tripOtpLength=4`, `tripOtpSalt='travacs-trip-otp-v1'`, `loginOtpLength=6`,
  `otpResendCooldownSeconds=30`, `appName='TravAcs'`, `appVersion='1.0.0'`, placeholder support
  email/phone.
- **Estimate (at create + accept):** `serviceCharge(min) = 70 × ceil(min/30)` per TravAcser;
  `estimate = serviceCharge × numTravAcsers + 100`. Accept-time `amountInrEstimate` on each
  assignment is **service charge only** (travel is a trip-level line item).
- **Actual bill (at `completeTrip`):** `minutes = max(1, round((now − startedAt)/60000))`,
  `serviceInr = 70 × ceil(minutes/30)`, `travelInr = 100` **only if** `request.travelCostCharged` is
  not already true (first assignment to complete), else 0; `amountInr = serviceInr + travelInr`. When
  travel is charged, `request.travelCostCharged` is set true in the same transaction (once-per-trip
  guard, retry-safe). Worked example: 12:48→17:46 = 4h58m → `ceil(298/30)=10` blocks → ₹700 + ₹100 =
  **₹800**.

---

## 10. Trip lifecycle state machine (CRITICAL — most cross-cutting behavior)
Two statuses evolve: the **request** `status` and each **assignment** `tripStatus`.

```
request.status:  broadcast ──accept(fills all slots)──► assigned ──(all assignments completed)──► completed
                    │  ▲                                    │  ▲                                     
     cancel/expire  │  │ reopen (a TravAcser cancels/       │  │ reopen (reschedule-decline/expire)  
                    ▼  │  declines/reschedule-expires)      ▼  │                                      
                 cancelled                               broadcast

assignment.tripStatus: assigned ──startTrip(TravAcser validates code)──► started ──completeTrip──► completed
                          │                                                 (cannot cancel/reschedule)
              cancel ─────┼───────────────────────────────────────────────► cancelled
```

Key rules enforced across server + UI:
- **A partially-filled request stays `broadcast`** (only flips to `assigned` when `acceptedCount >=
  numTravAcsers`). A TravAcser cancelling/declining/expiring **decrements `acceptedCount` and reopens**
  `assigned → broadcast`.
- **"Started" lives on the assignment, not the request.** The request `status` never becomes
  `started`. So requester-side UI must inspect `requestAssignmentsProvider`, not `request.status`, to
  know a trip started.
- **A `started` trip can only be ended** — never cancelled or rescheduled (server rejects with
  `TRIP_STARTED`/`ALREADY_STARTED`; UI hides the buttons).
- **Trips may start early** (parties meet before schedule; billing runs from recorded `startedAt`)
  **but can never be ended before `scheduledStartAt`** (`completeTrip` `EARLY_END`).
- **One accepted trip per IST day** per TravAcser (`acceptRequest` `ONE_PER_DAY`, active
  assignments only). Known theoretical millisecond race (documented gap).
- **Request marked `completed`** by `completeTrip` only when no assignment is `assigned`/`started` and
  at least one is `completed`/`closed`.

---

## 11. Cloud Functions (`firebase/functions/src/index.ts`) — 15 functions
Callables region `asia-south2` (`REGION`); scheduled region `asia-south1` (`SCHEDULER_REGION`).
Shared helpers: `serviceChargeInr`, `istDateKey` (IST day, UTC+5:30), `sendMulticastChunked`
(chunks 500/token, prunes dead tokens), `pushToUser`, `paymentStatusOf`.

| Function | Trigger | Behavior & guards (error `code`s) |
|---|---|---|
| **onRequestCreated** | onCreate `requests/{id}` | Only if `status=='broadcast'` and `serviceCity` set. If `genderRestricted && requesterGender`: stamp `genderWidenAt = createTime + 0.9×(scheduledStartAt−createTime)` and filter the volunteer query to same gender. Fan-out FCM (`new_request`) to approved+active TravAcsers in the same city, chunked, dead-token pruned. |
| **acceptRequest** | onCall (TravAcser) | Caller must be approved+active volunteer (`NOT_APPROVED`). Transaction: request must be `broadcast` (`ALREADY_TAKEN`), same city (`WRONG_CITY`), gender gate (`GENDER_MISMATCH` if strict + known requester gender + not widened + different gender), not already live-accepted (`ALREADY_ACCEPTED` — a *cancelled* prior assignment does NOT block re-accept), slots left (`ALREADY_TAKEN`), one-per-IST-day (`ONE_PER_DAY`). Writes the assignment (denormalized, `amountInrEstimate`=service charge, `tripStatus:'assigned'`), increments `acceptedCount`, flips request to `assigned` when full. Pushes requester (`assignment`). |
| **startTrip** | onCall (TravAcser only) | `uid==volunteerId`. Assignment must be `assigned` (`INVALID_STATE`). Sets `tripStatus:'started'`, `startedAt`, `otpStartedAt`. Pushes User (`trip_started`). (Code validation is client-side.) |
| **completeTrip** | onCall (TravAcser or requester) | Assignment must be `started` (`NOT_STARTED`). Reject if `now < scheduledStartAt` (`EARLY_END`). Bills from `startedAt`; writes `serviceChargeInr`, `travelCostInr` (once/trip via `travelCostCharged`), `amountInr`, `tripStatus:'completed'`, `paymentStatus:'pending'`. Marks request `completed` when no active assignment remains. Pushes both (`trip_completed`). |
| **rescheduleTrip** | onCall (requester only) | New start must be `now+1min … now+90d` (`BAD_SCHEDULE`). Request must be `broadcast`/`assigned` (`INVALID_STATE`). Reject if accepted & original time passed, or any assignment `started` (`ALREADY_STARTED`). Updates request + each `assigned` assignment's schedule, sets each `rescheduleStatus:'pending'` + `rescheduleDeadlineAt = now + 10%×remaining`, clears `noTravAcserNotifiedAt`, recomputes gender widen window. Pushes each TravAcser (`trip_rescheduled`). |
| **respondReschedule** | onCall (TravAcser) | Assignment `rescheduleStatus` must be `pending` (`NO_PENDING`). accept=true → `confirmed`; accept=false → `cancelled`+`declined`, decrement `acceptedCount`, reopen `assigned→broadcast`, push requester (`trip_cancelled`). |
| **cancelTrip** | onCall (either party) | Request not `completed`/`cancelled` (`INVALID_STATE`). **Requester:** reject if any assignment `started` (`TRIP_STARTED`); else request→`cancelled`, all active assignments→`cancelled`, push each TravAcser. **TravAcser:** their assignment must not be `started` (`TRIP_STARTED`) and must be `assigned` (`INVALID_STATE`); →`cancelled`, decrement count, reopen, push requester. |
| **markPaid** | onCall (requester only) | Assignment must be `completed` (`INVALID_STATE`). Sets `requesterPaidAt` (idempotent), recomputes `paymentStatus`. Push TravAcser (`payment_marked`). |
| **markReceived** | onCall (TravAcser) | Sets `travAcserReceivedAt`, recomputes `paymentStatus`. |
| **submitRating** | onCall (either party) | Stars integer 1–5, feedback ≤1000 chars. Assignment `completed` (`INVALID_STATE`). Derives rater/ratee; blocks a second rating from the same side (`ALREADY_RATED`); writes rating onto the assignment and updates ratee `ratingAvg`/`ratingCount` (rolling, rounded to 0.1). |
| **createRazorpayOrder** | onCall (requester only) | secrets `RAZORPAY_KEY_ID/SECRET`. Assignment `completed`, not paid (`ALREADY_PAID`), `amountInr>0` (`NO_AMOUNT`). **Reuses stored order only if `razorpayKeyId==current keyId`** (else mints fresh — auto-heals stale/test-key orders); stamps `razorpayOrderId`+`razorpayKeyId`. Returns `{orderId, keyId, amountPaise, amountInr, currency}`. |
| **verifyRazorpayPayment** | onCall (requester only) | secret `RAZORPAY_KEY_SECRET`. HMAC-SHA256 verify `orderId|paymentId` (timing-safe) (`BAD_SIGNATURE`). Assignment `completed`, `razorpayOrderId` matches (`ORDER_MISMATCH`). Sets `requesterPaidAt`+ids, recomputes `paymentStatus`. Push TravAcser. |
| **setVerification** | onCall (admin claim only) | Target profile role `volunteer`. Sets `verificationStatus` approved/rejected + `verifiedBy/At` + `rejectionReason`. Push volunteer (`verification_result`). |
| **logManualTrip** | onCall (admin claim only) | Requires `userDetails`, `travAcserDetails`, `tripDateMs`. Adds a `tripLogs` doc. |
| **expireStaleRequests** | scheduled every 5 min | For `broadcast` requests with `scheduledStartAt<=now+30m`, re-checked in a txn: at/after start & still unaccepted → `cancelled` (`cancelReason:'no_travacser'`, push `no_travacser_cancelled`); before start & not yet warned & live >10 min → set `noTravAcserNotifiedAt`, push `no_travacser_warning`. |
| **expireRescheduleConfirmations** | scheduled every 2 min | For assignments `rescheduleStatus=='pending'` past `rescheduleDeadlineAt`: cancel the slot (`expired`), decrement count, reopen; push both (`reschedule_expired`). |
| **widenGenderRequests** | scheduled every 2 min | For `genderRestricted==true && genderWidened==false` past `genderWidenAt`: set `genderWidened:true`, fan out to different-gender TravAcsers in the city (`new_request`), push requester (`gender_widened`). |

---

## 12. Security Rules (`firebase/firestore.rules`) — default-deny
Helpers: `isSignedIn`, `isAdmin` (`token.admin==true`), `profileData(uid)`, `isApprovedVolunteer`
(role volunteer + approved + active), `myCity`, `requestData`.
- **profiles/{uid}:** read self or admin. Create self only; `role∈{requester,volunteer}`,
  `ratingAvg==0`, `ratingCount==0`, volunteer must start `verificationStatus=='pending'`. Update self
  but **cannot change** `role`, `ratingAvg`, `ratingCount`, `verificationStatus`, `rejectionReason`.
  No delete.
- **requests/{id}:** read if requester, or its volunteer, or admin, or (`broadcast` +
  approved-volunteer + same city + gender backstop `genderRestricted==false || genderWidened==true ||
  requesterGender==my gender`). Create: `requesterId==uid`, `status∈{draft,broadcast}`,
  `volunteerId==null`, `serviceCity` string, `acceptedCount==0`, `numTravAcsers` int 1..10,
  `numTravellers` int 1..10, `genderWidened==false`. Update: **only** requester, only while
  `status∈{draft,broadcast}` and `acceptedCount==0`, and only to set `status=='cancelled'` (i.e.
  cancel-before-any-accept). No delete.
- **assignments (nested + collection-group):** direct read by that TravAcser, the requester, or admin;
  collection-group read gated on `resource.data.volunteerId==uid` (field, not doc id). **Writes:
  false** (functions only).
- **trips / ratings:** read by parties/admin; writes false. **tripLogs:** admin read; writes false.
- **devices/{uid}/tokens/{token}:** read+write self.

---

## 13. Composite indexes (`firestore.indexes.json`)
requests: `status+createdAt↓`, `status+serviceCity+createdAt↓`, `requesterId+createdAt↓`,
`volunteerId+status`, `status+scheduledStartAt`, `genderRestricted+genderWidened`. assignments
(collection-group): `rescheduleStatus+rescheduleDeadlineAt`; field override `volunteerId`
(collection + collection-group). profiles: `role+verificationStatus+isActive+serviceCity` (+`gender`),
`role+verificationStatus`.

---

## 14. Screen-by-screen behavior

### 14.1 Auth
- **SplashScreen:** `myProfileProvider.when` → loading/data show `_Loading` (Semantics "Loading
  TravAcs"); error shows message + Retry (`invalidate(myProfileProvider)`).
- **PhoneEntryScreen:** `+91 ` prefix; digits-only, exactly 10 (validator "Enter a valid 10-digit
  mobile number"). Submit → `requestOtp('+91<digits>')`; success announces + `go('/auth/otp?phone=…')`;
  failure announces `failureMessage`. Button/submit disabled while `authControllerProvider.isLoading`.
- **OtpEntryScreen:** numeric, max `loginOtpLength=6`, SMS autofill; validator exact length. Verify →
  `verifyOtp(code)`; success announces + `go('/')`. Resend enabled only when `_secondsLeft==0 &&
  !isLoading`; cooldown starts at `otpResendCooldownSeconds=30`, ticks down, announces "You can resend
  the code now." at 0.

### 14.2 Profile
- **CompleteProfileScreen:** `SegmentedButton<UserRole>` (requester/volunteer). Fields: full name
  (required), state (required; changing it resets city), city (required; disabled until state), gender
  (optional), DOB (optional; picker default now−25y, range now−100y…now), and **address (required only
  for volunteer)** / homeLocationText (requester only). Submit reads
  `firebaseAuth.currentUser?.phoneNumber`, calls `profileController.save(...)` (address only if
  volunteer; homeLocationText only if requester); success announces "Profile created…". Disabled while
  loading.
- **ProfileTabScreen:** shows Name, Role, Phone?, Gender?, region (`city, state` or "Not set"),
  Rating. Region tile opens `_RegionPickerSheet` (state dropdown + city radios; Save enabled only when
  both chosen) → `setServiceArea`. **Volunteer-only:** `_VerificationCard` (approved/pending/rejected
  icon+color+text) and `_AvailabilityTile` (`SwitchListTile` → `setAvailability`, subtitle "visible"
  vs "Hidden"). Sign out: `messagingRepository.unregisterToken()` then `authController.signOut()`.

### 14.3 Requester side
- **NewRequestScreen:** shown only if `my.profile.hasServiceArea` (else `_NeedsServiceArea`).
  Traveller dropdown 1..6 (default 1); changing it auto-sets `_numTravAcsers =
  suggestedTravAcsers(travellers)`. TravAcser dropdown range `min..numTravellers`
  (min=`suggestedTravAcsers`). Gender-preference dropdown (default `any_gender`); helper paragraph
  shown only for `strictSameGender`. Date chips (Today/Tomorrow/Day after) + custom picker (firstDate
  today, lastDate +60d); time picker. Duration dropdown {60,90,120,180,240,360,480} default 60.
  Required text: meeting point, destination, purpose; optional special note. Live estimate =
  `computeEstimate`. "Review & submit" validates form + schedule (both date & time), opens
  `_ReviewSheet`; on confirm → `create(...)` (passes `requesterGender = my.profile.gender`). Success:
  announce, reset, switch to My Requests tab (`shellTabIndexProvider.set(1)`), snackbar.
- **MyRequestsScreen (list→detail):** lists **active** requests (`status ∉
  {completed,closed,cancelled}`) as compact tiles: date·time, `RequestStatusChip`, a code/status line
  when `acceptedCount>0` (via `requestAssignmentsProvider`: "TravAcser assigned" / "In progress" /
  "Start code: NNNN" / "Start codes ready — open to view"), chevron. Tile is one Semantics button
  ("… Double tap to view details."). Tap → `RequestDetailScreen` (full-screen, scrollable, live).
  Detail shows status chip + labeled rows (trip time, pick-up, destination, users, TravAcsers filled,
  preference, purpose?, note?, estimated amount) + `Your TravAcser(s)` (`_RequestAssignments`, active
  only) + a "started — can't cancel/reschedule" note when started. Actions (`Wrap`): **Reschedule** if
  `canReschedule = !anyStarted && (acceptedCount==0 || now.isBefore(scheduledStartAt))`; **Cancel** if
  `!anyStarted`. `anyStarted = any active assignment tripStatus==started`. Cancel confirm →
  `notifier.cancel(id)` if `acceptedCount==0 && status.isCancellable` else `cancelTrip(id)`. Reschedule
  → date+time pickers → `reschedule(...)`. Per-assignment tile: shows start-code box
  (`_StartCodeDisplay`, "Read this code to your TravAcser") until in progress; when in progress shows
  "End trip & pay" enabled only when `canEnd = inProgress && !now.isBefore(effectiveStartAt)` →
  `completeTrip(...)` then chains `startTripPayment(...)`.
- **Requester TripHistoryScreen:** `myRequestsProvider`, terminal statuses only
  (completed/closed/cancelled), `HistoryControls` (filter all/completed/cancelled; sort newest/oldest;
  page size 15). Card: `when · destination`, "Cancelled" or `_Assignments` (completed/closed rows:
  `volunteerName · ₹amountInr · paymentStatus.label`, breakdown). Buttons: **Make payment** if
  `requesterPaidAt==null` → `startTripPayment(...)`; **Rate TravAcser** if `!ratedByRequester` →
  `showRatingSheet` → `submitRating`.

### 14.4 TravAcser side
- **AvailableRequestsScreen:** `!approved` → pending-verification message (support email/phone);
  `!hasCity` → set-service-area message; else `availableRequestsProvider` list of `RequestCard` +
  `_AcceptButton`. Accept → `accept(request.id)` (busy spinner); success announces "Accepted. See it
  under My Trips."
- **MyTripsScreen:** `myAssignmentsProvider` filtered to `isActive`. `_TripCard` header: date·time +
  `_StatusPill` (In progress / Ready to start / Scheduled). Reschedule banner if
  `needsRescheduleConfirm` (Continue → `respondReschedule(true)`, Cancel trip → `respondReschedule
  (false)`). Details + User contact (Semantics). Flags: `inProgress=isInProgress(now)`,
  `canStart=!inProgress && !needsRescheduleConfirm`, `canEnd=inProgress &&
  !now.isBefore(effectiveStartAt)`. **Start:** `_StartCodeEntry` (shown when `canStart`) →
  `_StartCodeDialog` (numeric, `maxLength=tripOtpLength=4`; wrong length / mismatch → inline error +
  announce; match → pop true) → `startTrip(...)`, announce "Code validated. The trip has started."
  **Cancel** shown only when `!inProgress` (confirm "releases your slot") → `cancelTrip`. **End trip**
  shown only when `inProgress`, disabled unless `canEnd` → `completeTrip`.
- **TravAcser TripHistoryScreen:** terminal assignments; earnings summary (`totalBilled` = Σ
  amountInr of non-cancelled; `totalReceived` = Σ where `paymentStatus==confirmed`). Filter/sort/page
  15. Card: `when · destination`, "Cancelled" or `duration min · ₹amountInr earned`, breakdown,
  payment label. Buttons: **Mark received** if `travAcserReceivedAt==null` → `markReceived`; **Rate the
  User** if `!ratedByVolunteer` → `submitRating`.

### 14.5 Shell, Admin, Menu
- **AppShell:** in `initState` (post-frame) registers FCM token, subscribes to token-refresh and
  foreground messages (announce + snackbar of `body ?? title`). Role tabs: requester {Request, My
  Requests, History, Profile}; volunteer {Available, My Trips, History, Profile}. `IndexedStack` +
  `NavigationBar`; tab change unfocuses + `shellTabIndexProvider.set` + announce. AppBar +
  `AppMenuDrawer`.
- **AdminScreen:** `TabController(3)` — Verifications (`pendingVolunteersProvider`, `_PendingCard`
  Approve/Reject; Reject opens optional-reason dialog), Active trips (`activeTripsProvider` rows), Manual
  entry (`logManualTrip`; requires date). Drawer = `AppMenuDrawer`.
- **AppMenuDrawer:** header (icon, name+version, Close), items: Contact us → `ContactUsScreen`; About
  → `showAboutDialog`; Rate us → "not on Play Store yet" dialog; Terms → `TermsScreen`; Privacy →
  `PrivacyPolicyScreen`; Sign out → confirm → announce + `unregisterToken()` + `signOut()`. Info
  screens are placeholder text; `ContactUsScreen` rows are copyable (Clipboard + announce).

---

## 15. Payments
Two mechanisms coexist:
1. **In-app Razorpay (LIVE)** — end trip → `createRazorpayOrder` → `startTripPayment`
   (`shared/trip_payment.dart`: opens the Razorpay checkout via `razorpay_flutter`, offers
   UPI/cards/GPay/wallets) → `verifyRazorpayPayment` (server HMAC verify → marks paid). Never surfaces
   raw SDK text (golden rule #1); cancels/errors are announced with curated messages. Credentials live
   only in Secret Manager; the client receives `keyId` at runtime.
2. **Manual two-sided confirmation (fallback)** — `markPaid` (requester) + `markReceived`
   (TravAcser) → `paymentStatus` pending→awaiting_other→confirmed.

---

## 16. Error taxonomy (`core/error/`)
`Failure` base: `message` (user-facing), `code`, `debugDetail` (logs only), `isRetryable`. Subtypes:
Network (retryable, "No internet…"), Auth, Permission, NotFound, Conflict, RateLimit (retryable),
Validation, Unavailable (retryable), Server, Unexpected. `failureMessage(e)` → `e.message` for a
Failure else generic. `mapFirebaseError` classifies (Functions → Auth → Firestore → Socket/Timeout →
passthrough → Unexpected), **reports non-fatally to Crashlytics**, returns the Failure — raw
codes/`toString()`/stack live only in `debugDetail`. `mapErrorToFailure()` maps stream errors.
`ErrorFallback` is the release ErrorWidget.

---

## 17. Regression safety net (tests)
Run: `cd app; flutter analyze; flutter test` (**73 tests**) and, from `firebase/`, the emulator suites
(`npx -y firebase-tools@13 emulators:exec --only firestore --project demo-travacs "npm --prefix
functions test"` = **31 functions tests**; `… "npm --prefix rules-tests test"` = **30 rules tests**).

| Suite | Guards |
|---|---|
| `app/test/domain_test.dart` | billing math (`serviceCharge`, `computeEstimate` incl. the ₹800 example), `suggestedTravAcsers`, constants (`hourlyRateInr==140`, `travelCostInr==100`), enum mapping |
| `app/test/provider_test.dart` | `availableRequestsProvider` filtering incl. gender feed hiding |
| `app/test/repository_test.dart` | create writes `estimatedAmountInr==380`, error→Failure mapping, callable wiring |
| `app/test/accessibility_test.dart` | `meetsGuideline` (tap-target/labeled/contrast) + semantic labels — **`RequestCard` MergeSemantics is guarded here; do not remove it** |
| `app/test/my_requests_flow_test.dart` | compact list → detail navigation |
| `app/test/widget_flow_test.dart` | rating sheet gating, OTP entry short-code rejection, resend cooldown |
| `app/test/error_mapper_test.dart` | no raw text leaks; code→Failure mapping |
| `app/test/trip_otp_test.dart` | deterministic start-code |
| `app/test/menu_test.dart`, `messaging_repository_test.dart`, `widget_test.dart` | drawer, FCM token register/unregister, smoke |
| `firebase/functions/test/index.test.ts` (31) | accept FCFS + guards (gender, one-per-day), start/complete billing incl. once-per-trip travel, cancel-started reject, reschedule guards, two-sided payment, ratings, razorpay verify, admin gates |
| `firebase/rules-tests/test/firestore.test.js` (30) | default-deny, function-only writes, region + gender read-gating, cancel-before-accept |

---

## 18. Invariants checklist (do NOT regress)
1. **No raw errors to users** — everything through `Failure`/`failureMessage`; raw detail only in
   `debugDetail`→Crashlytics; global boundary in `main.dart`.
2. **Accessibility first-class** — semantic labels on every control; `A11y.announce` on status
   changes; status never colour-only (text+icon+Semantics); `MergeSemantics` on cards; icon-only
   buttons set `Icon(semanticLabel:)`; touch targets ≥48dp; text scale clamp `[1.0,1.8]`.
3. **Privileged writes server-only** — clients cannot set `role`, `verificationStatus`, ratings,
   `volunteerId`, amounts, `tripStatus`; assignments/trips are function-only. Only two client Firestore
   writes exist: create request, and cancel-before-any-accept.
4. **Started trip is locked** — no cancel/reschedule once an assignment is `started`; cannot end
   before `scheduledStartAt`; may start early.
5. **Travel cost once per trip** (`travelCostCharged`); service charge = ₹140/hr in 30-min blocks
   rounded up. Client and server formulas must stay identical.
6. **Gender restriction** — only `strict_same_gender` + known requester gender restricts, until the
   last 10% of lead time (`widenGenderRequests`). `acceptRequest` is the authoritative gate.
7. **Region-scoped matching** — a TravAcser only sees/accepts same-`serviceCity` broadcast requests.
8. **Region pinning** — callables `asia-south2`; scheduled `asia-south1`; client
   `functionsProvider` must match.
9. **Secrets never in the repo** — Razorpay/config regenerated locally.

---

## 19. Known gaps (documented, not bugs to "fix" incidentally)
- One-trip-per-day has a theoretical millisecond race (robust fix = a deterministic
  `volunteerDailySlots/{uid_ISTdate}` guard doc).
- Offline start-code has no true physical-presence guarantee (both sides can compute it) — intentional.
- Partial multi-TravAcser lifecycle: a partially-filled request stays `broadcast`; starting one
  assignment doesn't freeze remaining slots; some complete+cancel combos don't fully reconcile the
  parent status.
- Functions runtime Node 20 deprecated (decommission 2026-10-30) — bump to 22.
- M11 store-release paused (debug signing key; `INTERNET`/`POST_NOTIFICATIONS` only in debug/profile
  manifests) — see `docx/m11-store-release-plan.md`.
