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

**Pricing (current):** service charge **₹149/hr per TravAcser serving 1 traveller, ₹210/hr serving 2**
(one TravAcser assists up to two people); **travel ₹100 per TravAcser** (× number of TravAcsers). Minimum
1-hour bill; after the first hour, extra minutes past each whole hour round ≤14→none, 15–40→+30 min,
41–60→+1 h. **TEST PHASE: only ₹1 is collected at checkout** (real amount stays on the doc + in history).
See §9.

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
| `requests/{id}` | client `create`; requester may only `cancel`; all else functions | `requesterId`, `requesterName?`, `volunteerId`(null), `status`, `serviceArea`, `serviceCity`, `acceptedCount`, `numTravellers`, `numTravAcsers`, `genderPreference`, `requesterGender?`, `genderRestricted`, `genderWidened`, `genderWidenAt?`, `scheduledDate`, `startTime`, `scheduledStartAt`, `expectedDurationMinutes`, `meetingPoint`, `destination`, `purpose?`, `specialNote?`, `estimatedAmountInr`, `tripAmountInr`, `paymentStatus`, `requesterPaidAt`, `razorpayOrderId`, `razorpayKeyId`, `razorpayAmountInr`, `razorpayPaymentId`, `noTravAcserNotifiedAt?`, `cancelReason?`, `createdAt`, `updatedAt` |
| `requests/{id}/assignments/{volunteerId}` | **functions only** | contact pair (`volunteerId/Name/Phone`, `requesterId/Name/Phone`), denormalized summary (`scheduledDate`, `startTime`, `scheduledStartAt`, `expectedDurationMinutes`, `meetingPoint`, `destination`, `genderPreference`, `numTravellers`, `amountInrEstimate`), `tripStatus` (assigned/started/completed/closed/cancelled), `acceptedAt`, `startedAt`, `otpStartedAt`, `endedAt`, `durationMinutes`, `serviceChargeInr`, `travelCostInr`, `amountInr`, `paymentStatus`, `requesterPaidAt`, `travAcserReceivedAt`, `razorpayOrderId`, `razorpayKeyId`, `razorpayAmountInr`, `razorpayPaymentId`, `rescheduleStatus`, `rescheduleDeadlineAt`, ratings (`requesterRatingStars/Feedback`, `volunteerRatingStars/Feedback`) |
| `devices/{uid}/tokens/{token}` | client (self) | `platform`, `updatedAt` (FCM tokens) |
| `tripLogs/{id}` | functions only (`logManualTrip`) | admin telemetry (manual + future app trips) |
| `trips/{id}`, `ratings/{id}` | functions only | rules present; ratings actually live on the assignment |

> **No SMS trip-start OTP / `secrets` subcollection.** Trip start uses a deterministic **offline
> start-code** computed identically on both clients (§8). The doc `status` does **not** flip to
> `started` on trip start — only the *assignment* `tripStatus` does (see §10, critical).

---

## 6. Domain entities & enums (`domain/entities/`)
- **`Request`** — request fields above + **static billing helpers** (source of truth mirrored on the
  server): `billedHours(min)` (min 1 h, then per-hour rounding ≤14→0, 15–40→+0.5, 41–60→+1),
  `hourlyRateFor(travellersServed)` (₹149 solo / ₹210 pair), `pairServingCount(travellers, travAcsers)`
  = `clamp(travellers − travAcsers, 0, travAcsers)`, `computeEstimate(min, numTravellers,
  numTravAcsers)` = `billedHours × (pair×210 + solo×149) + 100×numTravAcsers`,
  `suggestedTravAcsers(t)=(t+1)~/2`. Getters: `slotsRemaining`, `isFull`, `durationHours`.
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
| `myPendingDuesProvider` | Provider | requester's completed trips with a trip-level bill (`tripAmountInr>0`) that are unpaid; blocks new request creation (legacy no-total trips excluded) |
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
  `cancelTrip`, `respondReschedule`, `completeTrip`, `startTrip`, `createRazorpayOrder`,
  `verifyRazorpayPayment`, `submitRating`.
- `adminControllerProvider`: `approve(uid)`, `reject(uid,reason)`, `logManualTrip(...)`.

Repository→callable mapping (`FirestoreRequestRepository`): `acceptRequest`, `startTrip`,
`completeTrip`, `rescheduleTrip`, `respondReschedule`, `cancelTrip`, `submitRating`,
`createRazorpayOrder`, `verifyRazorpayPayment` are all Cloud Functions callables.
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
- Constants (`constants.dart`): `rateSoloInr=149`, `ratePairInr=210`, `travelCostInr=100` (**per
  TravAcser**), `tripOtpLength=4`, `tripOtpSalt='travacs-trip-otp-v1'`, `loginOtpLength=6`,
  `otpResendCooldownSeconds=30`, `appName='TravAcs'`, `appVersion='1.0.0'`, placeholder support
  email/phone. Server mirrors: `RATE_SOLO_INR=149`, `RATE_PAIR_INR=210`, `TRAVEL_COST_INR=100`,
  `TEST_BILL_INR=1`.
- **Billed hours** (`billedHours(min)`): minimum **1 hour**; after the first hour, extra minutes past
  each whole hour round ≤14→0, 15–40→+0.5 h, 41–60→+1 h (repeats every hour). E.g. 1h14m→1, 1h15m–
  1h40m→1.5, 1h41m–2h→2.
- **Per-TravAcser rate:** ₹149/hr serving one traveller, ₹210/hr serving two. Across the N
  TravAcsers on a trip, `pairCount = clamp(numTravellers − N, 0, N)` bill ₹210, the rest ₹149
  (deterministic order = sort by volunteerId).
- **Estimate (create):** `billedHours(expDur) × (pair×210 + solo×149) + 100 × numTravAcsers`.
  Accept-time `amountInrEstimate` per assignment = `billedHours(expDur) × 149 + 100` (assumes solo;
  the ₹210 split resolves only at completion when N is known).
- **Actual bill (at `completeTrip`, per assignment):** `minutes = max(1, round((now −
  startedAt)/60000))`, `serviceInr = round(billedHours(minutes) × rate)`, `travelInr = 100` (always,
  per TravAcser); `amountInr = serviceInr + travelInr`. All started assignments are billed together
  (see §10 conclude-all). Worked example: 2 travellers, 1 TravAcser, 100 min → `billedHours=1.5` ×
  ₹210 = ₹315 + ₹100 = **₹415**.
- **TEST PHASE:** `createRazorpayOrder` overrides the checkout amount to **₹1** (`TEST_BILL_INR`); the
  real `amountInr` stays on the assignment (Trip History + estimates show real amounts). Removing the
  override needs no data cleanup.

---

## 10. Trip lifecycle state machine (CRITICAL — most cross-cutting behavior)
Two statuses evolve: the **request** `status` and each **assignment** `tripStatus`.

```
request.status:  broadcast ──accept(fills all slots)──► assigned ──(one party ends → ALL billed)──► completed
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
- **One party ending concludes the trip for ALL** — `completeTrip` bills **every** `started`
  assignment together, closes any still-`assigned` (unstarted) ones, and marks the request
  `completed` in the same transaction. Individual TravAcsers do not each end their own slice.

---

## 11. Cloud Functions (`firebase/functions/src/index.ts`) — 15 functions
Callables region `asia-south2` (`REGION`); scheduled region `asia-south1` (`SCHEDULER_REGION`).
Shared helpers: `billedHours`, `pairServingCount`, `istDateKey` (IST day, UTC+5:30),
`sendMulticastChunked` (chunks 500/token, prunes dead tokens), `pushToUser`, `paymentStatusOf`.

| Function | Trigger | Behavior & guards (error `code`s) |
|---|---|---|
| **onRequestCreated** | onCreate `requests/{id}` | Only if `status=='broadcast'` and `serviceCity` set. If `genderRestricted && requesterGender`: stamp `genderWidenAt = createTime + 0.9×(scheduledStartAt−createTime)` and filter the volunteer query to same gender. Fan-out FCM (`new_request`) to approved+active TravAcsers in the same city, chunked, dead-token pruned. |
| **acceptRequest** | onCall (TravAcser) | Caller must be approved+active volunteer (`NOT_APPROVED`). Transaction: request must be `broadcast` (`ALREADY_TAKEN`), same city (`WRONG_CITY`), gender gate (`GENDER_MISMATCH` if strict + known requester gender + not widened + different gender), not already live-accepted (`ALREADY_ACCEPTED` — a *cancelled* prior assignment does NOT block re-accept), slots left (`ALREADY_TAKEN`), one-per-IST-day (`ONE_PER_DAY`). Writes the assignment (denormalized, `amountInrEstimate = billedHours(dur)×149 + 100`, `tripStatus:'assigned'`), increments `acceptedCount`, flips request to `assigned` when full. Pushes requester (`assignment`). |
| **startTrip** | onCall (TravAcser only) | `uid==volunteerId`. Assignment must be `assigned` (`INVALID_STATE`). Sets `tripStatus:'started'`, `startedAt`, `otpStartedAt`. Pushes User (`trip_started`). (Code validation is client-side.) |
| **completeTrip** | onCall (TravAcser or requester) | Caller's assignment must be `started` (`NOT_STARTED`); reject if `now < scheduledStartAt` (`EARLY_END`). **Concludes for ALL:** bills every `started` assignment (each `serviceInr = round(billedHours(minutes) × rate)` with the ₹210/₹149 split, `travelCostInr=100`, `amountInr`, `paymentStatus:'pending'`), closes any still-`assigned` ones, and stamps the **whole-trip total** on the request (`tripAmountInr = Σ amountInr`, `paymentStatus:'pending'`), marking it `completed`. Pushes requester + each billed TravAcser (`trip_completed`). Returns `{ok, code}`. |
| **rescheduleTrip** | onCall (requester only) | New start must be `now+1min … now+3d` — beyond the day-after window rejects (`BAD_SCHEDULE`, "create a new trip"). Request must be `broadcast`/`assigned` (`INVALID_STATE`). Reject if accepted & original time passed, or any assignment `started` (`ALREADY_STARTED`). Updates request + each `assigned` assignment's schedule, sets each `rescheduleStatus:'pending'` + `rescheduleDeadlineAt = now + clamp(10%×remaining, 10min, remaining)` (min 10-min window so a short-notice reschedule isn't released almost instantly), clears `noTravAcserNotifiedAt`, recomputes gender widen window. Pushes each TravAcser (`trip_rescheduled`). |
| **respondReschedule** | onCall (TravAcser) | Assignment `rescheduleStatus` must be `pending` (`NO_PENDING`). accept=true → `confirmed`; accept=false → `cancelled`+`declined`, decrement `acceptedCount`, reopen `assigned→broadcast`, push requester (`trip_cancelled`). |
| **cancelTrip** | onCall (either party) | Request not `completed`/`cancelled` (`INVALID_STATE`). **Requester:** reject if any assignment `started` (`TRIP_STARTED`); else request→`cancelled`, all active assignments→`cancelled`, push each TravAcser. **TravAcser:** their assignment must not be `started` (`TRIP_STARTED`) and must be `assigned` (`INVALID_STATE`); →`cancelled`, decrement count, reopen, push requester. |
| **markPaid / markReceived** | REMOVED | The legacy two-sided per-assignment payment callables were deleted (payment is now one total per trip; see `createRazorpayOrder`/`verifyRazorpayPayment`/`razorpayWebhook`). |
| **razorpayWebhook** | onRequest (asia-south2) | secret `RAZORPAY_WEBHOOK_SECRET`. Durable server-side payment reconciliation: Razorpay POSTs a signed event; HMAC-SHA256 of the RAW body is verified, then on `payment.captured`/`order.paid` the trip is looked up by `razorpayOrderId` and marked paid (idempotent — a paid trip is untouched). This is the source of truth even if the client never calls `verifyRazorpayPayment`. |
| **submitRating** | onCall (either party) | Stars integer 1–5, feedback ≤1000 chars. Assignment `completed` (`INVALID_STATE`). Derives rater/ratee; blocks a second rating from the same side (`ALREADY_RATED`); writes rating onto the assignment and updates ratee `ratingAvg`/`ratingCount` (rolling, rounded to 0.1). |
| **createRazorpayOrder** | onCall (requester only) | secrets `RAZORPAY_KEY_ID/SECRET`. **Trip-level** (keyed by `requestId`, not per TravAcser): request `completed`, not paid (`ALREADY_PAID`), real `tripAmountInr>0` (`NO_AMOUNT`). **TEST PHASE: charges/returns `TEST_BILL_INR`=₹1** (checkout shows ₹1; real `tripAmountInr` untouched). Reuses a stored order only if `razorpayKeyId==current keyId` AND `razorpayAmountInr==billed` (else mints fresh); stamps `razorpayOrderId`+`razorpayKeyId`+`razorpayAmountInr` on the **request**. Returns `{orderId, keyId, amountPaise, amountInr(=1), currency}`. |
| **verifyRazorpayPayment** | onCall (requester only) | secret `RAZORPAY_KEY_SECRET`. **Trip-level** (keyed by `requestId`). HMAC-SHA256 verify `orderId|paymentId` (timing-safe) (`BAD_SIGNATURE`). Request `completed`, `razorpayOrderId` matches (`ORDER_MISMATCH`). Marks the **whole trip** paid: request `requesterPaidAt`+`paymentStatus:'confirmed'`, and stamps every `completed` assignment `requesterPaidAt`+`paymentStatus:'confirmed'`. Pushes each TravAcser. One payment covers all TravAcsers; the admin team distributes each share manually off-app. |
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
  `numTravellers` int 1..10, `genderWidened==false`, **and a field allowlist** — the create may only
  carry the client-writable fields (blocks pre-seeding server-managed `tripAmountInr`, `paymentStatus`,
  `requesterPaidAt`, `razorpay*`, etc.). Update: **only** requester, only while `status∈{draft,broadcast}`
  and `acceptedCount==0`, only to set `status=='cancelled'`, **and `affectedKeys().hasOnly(['status',
  'updatedAt'])`** (so the cancel can't also change ownership/amounts/payment fields). No delete.
- **assignments (nested + collection-group):** direct read by that TravAcser, the requester, or admin;
  collection-group read gated on `resource.data.volunteerId==uid` **or** `resource.data.requesterId==uid`
  (fields, not doc id) — so a TravAcser lists their own trips and a requester lists their own trips'
  assignments (used for the pending-dues check). **Writes: false** (functions only).
- **trips / ratings:** read by parties/admin; writes false. **tripLogs:** admin read; writes false.
- **devices/{uid}/tokens/{token}:** read+write self.

---

## 13. Composite indexes (`firestore.indexes.json`)
requests: `status+createdAt↓`, `status+serviceCity+createdAt↓`, `requesterId+createdAt↓`,
`volunteerId+status`, `status+scheduledStartAt`, `genderRestricted+genderWidened`. assignments
(collection-group): `rescheduleStatus+rescheduleDeadlineAt`; field overrides `volunteerId` **and
`requesterId`** (collection + collection-group). profiles:
`role+verificationStatus+isActive+serviceCity` (+`gender`), `role+verificationStatus`.

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
  (required), state (required; changing it resets city), city (required; disabled until state),
  **gender (REQUIRED — validator "Please select your gender")**, DOB (optional; picker default now−25y,
  range now−100y…now), and **address (required only for volunteer)** / homeLocationText (requester
  only). Submit reads `firebaseAuth.currentUser?.phoneNumber`, calls `profileController.save(...)`
  (address only if volunteer; homeLocationText only if requester); success announces "Profile
  created…". Disabled while loading.
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
  → **Today/Tomorrow/Day-after chip dialog** (no custom date beyond day-after; advises "create a new
  trip") + time picker → `reschedule(...)`. A **Get help** button (→ `ContactUsScreen`) also sits in
  the actions `Wrap`. Per-assignment tile shows contact + status + the start-code box
  (`_StartCodeDisplay`, "Read this code to your TravAcser") until in progress. When any assignment is
  in progress, a **single trip-level "End trip & pay"** button (not per TravAcser) is shown, enabled
  only when `canEnd = now >= scheduledStartAt` → `completeTrip(...)` (concludes all) then chains the
  single `startTripPayment(requestId)`.
- **NewRequestScreen (dues guard):** warms `myRequestsProvider` in build; on Submit, if it's still
  loading it asks to retry, and if `myPendingDuesProvider` (completed-but-unpaid trips) is non-empty →
  alert dialog "Alert, you have pending dues, kindly clear them before creating new ones." and the
  request is NOT created. Otherwise proceeds to the review sheet.
- **Requester TripHistoryScreen:** `myRequestsProvider`, terminal statuses only
  (completed/closed/cancelled), `HistoryControls` (filter all/completed/cancelled; sort newest/oldest;
  page size 15). Card: `when · destination`, "Cancelled"/"Completed", then for a completed trip a
  **single trip total + payment status** (`Trip total: ₹tripAmountInr · Paid/Payment pending`), a
  per-TravAcser **breakdown** (`volunteerName · ₹amountInr` + breakdown, or "Not started — no charge"
  for a `closed` slice) with a per-TravAcser **Rate TravAcser** button, and card-level **Get help** +
  a **single "Make payment"** button (`startTripPayment(requestId)`, collects ₹1 in test phase) shown
  only while `!isPaid`.

### 14.4 TravAcser side
- **AvailableRequestsScreen:** `!approved` → pending-verification message (support email/phone);
  `!hasCity` → set-service-area message; else `availableRequestsProvider` list of `RequestCard` +
  `_AcceptButton`. Accept → `accept(request.id)` (busy spinner); success announces "Accepted. See it
  under My Trips."
- **MyTripsScreen:** `myAssignmentsProvider` filtered to `isActive`. `_TripCard` header: date·time +
  `_StatusPill` (In progress / Ready to start / Scheduled). Reschedule banner if
  `needsRescheduleConfirm` (Continue → `respondReschedule(true)`, Cancel trip → `respondReschedule
  (false)`). Actions `Wrap` includes **Get help** (→ Contact us). Details + User contact (Semantics).
  Flags: `inProgress=isInProgress(now)`,
  `canStart=!inProgress && !needsRescheduleConfirm`, `canEnd=inProgress &&
  !now.isBefore(effectiveStartAt)`. **Start:** `_StartCodeEntry` (shown when `canStart`) →
  `_StartCodeDialog` (numeric, `maxLength=tripOtpLength=4`; wrong length / mismatch → inline error +
  announce; match → pop true) → `startTrip(...)`, announce "Code validated. The trip has started."
  **Cancel** shown only when `!inProgress` (confirm "releases your slot") → `cancelTrip`. **End trip**
  shown only when `inProgress`, disabled unless `canEnd` → `completeTrip`.
- **TravAcser TripHistoryScreen:** terminal assignments; earnings summary (`totalBilled` = Σ
  amountInr of non-cancelled; `totalReceived` = Σ where `paymentStatus==confirmed`). Filter/sort/page
  15. Card: `when · destination`, "Cancelled" or `duration min · ₹amountInr earned`, breakdown,
  **payment status** (informational — no "Mark received" step; the payout is a manual admin transfer).
  A **Get help** button (→ Contact us) shows on every card. **Rate the User** if `!ratedByVolunteer` →
  `submitRating`.

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
**One total payment per trip.** The User pays a single amount covering ALL TravAcsers on the trip to
the app's Razorpay account; the **admin team distributes each TravAcser's share manually, off-app**.
Payment state lives on the **request** (`tripAmountInr`, `requesterPaidAt`, `paymentStatus`,
`razorpay*`), not per assignment — the per-assignment `amountInr` remains only as the payout breakdown.
- **In-app Razorpay (LIVE)** — end trip → `createRazorpayOrder(requestId)` → `startTripPayment`
  (`shared/trip_payment.dart`: opens the Razorpay checkout via `razorpay_flutter`, offers
  UPI/cards/GPay/wallets) → `verifyRazorpayPayment(requestId)` (server HMAC verify → marks the **whole
  trip** paid + stamps every completed assignment). Never surfaces raw SDK text (golden rule #1);
  cancels/errors are announced with curated messages. Credentials live only in Secret Manager; the
  client receives `keyId` at runtime. **TEST PHASE: only ₹1 is collected** (real `tripAmountInr` stays
  on the request + in history).
- There is a **single** "End trip & pay" (active trip) / "Make payment" (Trip History) button per
  trip — NOT one per TravAcser. The TravAcser side has **no "Mark received"** step (their payout is a
  manual admin transfer); their history just shows the payment status.
- **Reconciliation:** a signed **`razorpayWebhook`** (onRequest) is the durable source of truth —
  even if the client never calls `verifyRazorpayPayment`, Razorpay's webhook marks the trip paid
  (idempotently). Client verification is an optimization. The legacy per-assignment
  `markPaid`/`markReceived` callables were **removed**.

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
Run: `cd app; flutter analyze; flutter test` (**82 tests**) and, from `firebase/`, the emulator suites
(`npx -y firebase-tools@13 emulators:exec --only firestore --project demo-travacs "npm --prefix
functions test"` = **50 functions tests**; `… "npm --prefix rules-tests test"` = **38 rules tests**).

| Suite | Guards |
|---|---|
| `app/test/domain_test.dart` | billing math (`billedHours` rounding, `computeEstimate` incl. a **client↔server parity vector table**, `pairServingCount`), `suggestedTravAcsers`, constants, **`Assignment.amountBreakdown` rate follows the amount (solo estimate vs ₹210 pair)**, **enum `fromWire` safe fallback on unknown values** |
| `app/test/provider_test.dart` | `availableRequestsProvider` filtering incl. gender feed hiding; **`myPendingDuesProvider`** (unpaid-with-bill blocks, paid/legacy don't) |
| `app/test/repository_test.dart` | create writes `estimatedAmountInr==520`, error→Failure mapping, callable wiring |
| `app/test/accessibility_test.dart` | `meetsGuideline` (tap-target/labeled/contrast) + semantic labels — **`RequestCard` MergeSemantics is guarded here; do not remove it** |
| `app/test/my_requests_flow_test.dart` | compact list → detail navigation |
| `app/test/widget_flow_test.dart` | rating sheet gating, OTP entry short-code rejection, resend cooldown |
| `app/test/error_mapper_test.dart` | no raw text leaks; code→Failure mapping |
| `app/test/trip_otp_test.dart` | deterministic start-code |
| `app/test/menu_test.dart`, `messaging_repository_test.dart`, `widget_test.dart` | drawer, FCM token register/unregister, smoke |
| `firebase/functions/test/index.test.ts` (50) | accept FCFS + guards (gender, one-per-day, **past-start reject**), **freeze-parent-on-start** (no accept after one TravAcser starts a partially-filled request), complete billing (split rate + ₹100/TravAcser) + **conclude-all** (incl. mixed started/assigned) + pair rate, EARLY_END, cancel-started reject, reschedule guards + day-after bound, **reschedule-vs-started-lock** (respond/expiry), **idempotent start/complete**, **expireStaleRequests / expireRescheduleConfirmations**, **widenGenderRequests bounded to broadcast**, **createRazorpayOrder (₹1 override + reuse + already-paid)**, **razorpayWebhook (bad/missing signature, ignored event, payment.captured marks-paid + idempotent)**, razorpay verify (trip-level), ratings, admin gates |
| `firebase/rules-tests/test/firestore.test.js` (38) | default-deny, function-only writes, region + gender read-gating, requester collection-group read, cancel-before-accept, **create field-allowlist (forged payment fields)**, **create requires a `scheduledStartAt` timestamp**, **cancel affectedKeys (can't change ownership/amounts)**, **gender is immutable on profile update**, **gender-constrained available-requests listing is authorizable (per-gender results)** |

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
   before `scheduledStartAt`; may start early. **Starting also freezes the parent request** (a
   partially-filled `broadcast`/`assigned` request flips to `started`), and `acceptRequest` rejects a
   request whose `scheduledStartAt` has passed — so no TravAcser can join a trip that is underway or
   past its window.
5. **Billing** — service charge ₹149/hr (serves 1) / ₹210/hr (serves 2) per TravAcser via even
   split; billed hours = min 1 h + per-hour rounding (≤14→0, 15–40→+30 m, 41–60→+1 h); travel ₹100
   **per TravAcser**. Client and server formulas must stay identical. **TEST PHASE: checkout collects
   ₹1** while the stored `amountInr` stays real.
6. **One party ends → concluded for all** — `completeTrip` bills every `started` assignment and
   completes the request in one transaction; TravAcsers don't each end their own slice.
7. **One total payment per trip** — the User pays a single amount (all TravAcsers' shares) to the
   app's Razorpay account; payment state lives on the request (`tripAmountInr`/`requesterPaidAt`);
   admin distributes each share manually off-app. No per-TravAcser payment or "Mark received".
   **TEST PHASE: checkout collects ₹1** while the stored amounts stay real.
8. **Reschedule window** — Today/Tomorrow/Day-after only (server bound ≤ now+3d); the reschedule
   hold gives the TravAcser a yes/no window (≥10 min) before the slot reopens.
9. **Gender restriction** — only `strict_same_gender` + known requester gender restricts, until the
   last 10% of lead time (`widenGenderRequests`). `acceptRequest` is the authoritative gate.
10. **Region-scoped matching** — a TravAcser only sees/accepts same-`serviceCity` broadcast requests.
11. **Region pinning** — callables `asia-south2`; scheduled `asia-south1`; client
    `functionsProvider` must match.
12. **Profile gender is required.** **Secrets never in the repo** — Razorpay/config regenerated locally.

---

## 19. Known gaps (documented, not bugs to "fix" incidentally)
- **Pair-rate identity is positional.** In a multi-TravAcser trip, `completeTrip` assigns the ₹210
  (serves-two) rate to the first `pairCount` started assignments *sorted by volunteerId* — the app
  does not track which TravAcser actually served two travellers. When TravAcsers ran different
  durations, the trip total depends on which id gets the pair rate. Accepted for the even-split model
  (no per-traveller attendance tracking); revisit if attendance is ever recorded.
- **Accept-time earning estimate assumes the solo rate** (₹149/hr) even when the trip guarantees a
  pair; the final `completeTrip` bill (which may apply ₹210) is authoritative. Informational only.
  (`Assignment.amountBreakdown` now derives its rate from the shown amount, so the per-TravAcser line
  no longer contradicts the total — a pair trip reads ₹210/hr once billed.)
- **Pending-dues block is client-side.** `NewRequestScreen` warms `myRequesterAssignmentsProvider`
  and blocks submit while it loads or when dues exist, but request creation is still a direct client
  Firestore write, so the block is not server-authoritative (a modified client or a cross-device race
  could bypass it). A robust fix is a server-side dues flag + a callable `createRequest` transaction.
- **Gender is immutable after profile creation** (rules block changing it — H4), and request
  visibility/acceptance trust it. Residual gap: a profile can still be *created* with a missing/invalid
  `gender`, and `strict_same_gender` enforcement is otherwise client-driven at request time.
- One-trip-per-day has a theoretical millisecond race (robust fix = a deterministic
  `volunteerDailySlots/{uid_ISTdate}` guard doc).
- Offline start-code has no true physical-presence guarantee (both sides can compute it) — intentional.
- Partial multi-TravAcser lifecycle: a partially-filled request now **freezes to `started`** when one
  TravAcser starts (no further accepts), and accepts past `scheduledStartAt` are rejected — but the
  remaining unfilled slots are simply abandoned, and some complete+cancel combinations still don't
  fully reconcile the parent status.
- Functions runtime Node 20 deprecated (decommission 2026-10-30) — bump to 22.
- M11 store-release paused (debug signing key; `INTERNET`/`POST_NOTIFICATIONS` only in debug/profile
  manifests) — see `docx/m11-store-release-plan.md`.
