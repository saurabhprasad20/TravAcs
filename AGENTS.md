# TravAcs — Agent & Developer Guide

> **Read this first.** This is the single entry point for anyone (human or AI agent) picking up
> this project. It gives you complete, verified context so you don't have to guess: what the app
> is, how it's built, where everything lives, the exact commands for every essential operation, and
> the invariants you must not break. Deeper design lives in [`docx/design_travacs.md`](docx/design_travacs.md);
> backend test details in [`firebase/TESTING.md`](firebase/TESTING.md).

---

## TL;DR
- **TravAcs** is an accessibility-first mobile app that pairs **visually-impaired Users** with
  **verified TravAcsers** (assistants) for **paid (₹135/hr) in-person travel assistance**.
- **Stack:** Flutter (Dart) front end + **Firebase** back end (Phone-OTP Auth, Cloud Firestore,
  Cloud Functions, FCM, Crashlytics). Firebase project: **`travacs-dev`**, functions region
  **`asia-south2`**.
- **Status:** Milestones **M0–M10 are done, checkpointed, and CI-green.** **M11 (Play-Store release)
  is documented but paused** — see [`docx/m11-store-release-plan.md`](docx/m11-store-release-plan.md).
- **Dev machine:** Windows 11 on **ARM64**, corporate-**managed** (no admin). Toolchain is portable
  (paths below). Shell is **PowerShell**.
- **Golden invariant:** users must **never** see raw errors/stack traces, and **accessibility is
  first-class** — see [Golden Rules](#golden-rules-do-not-regress-these).

## First 15 minutes (new agent quickstart)
1. Skim this file top-to-bottom, then [`docx/design_travacs.md`](docx/design_travacs.md) §0–§14.
2. Regenerate the gitignored Firebase config (see [First-time setup](#a-first-time-setup-on-a-fresh-clone)) —
   the app **will not build** without `app/lib/firebase_options.dart`.
3. `cd app; flutter pub get; flutter analyze; flutter test` — expect **53 passing tests**, analyzer clean.
4. Build + install on the connected phone (see [Build & run](#b-build--run-on-the-phone)).
5. Before changing anything, read the [Golden Rules](#golden-rules-do-not-regress-these).

---

## Golden Rules (do NOT regress these)
1. **No raw errors to users — ever.** Every user-facing error message goes through the sealed
   `Failure` taxonomy in `app/lib/core/error/failure.dart` and `mapFirebaseError()` in
   `app/lib/core/error/firebase_error_mapper.dart`. UI surfaces errors via `failureMessage(e)`. Raw
   detail (codes, `toString()`, stack traces) lives **only** in `Failure.debugDetail` and is sent to
   Crashlytics via `error_reporter.dart` — never rendered. There is a global boundary in `main.dart`
   (`FlutterError.onError`, `PlatformDispatcher.onError`, release `ErrorWidget.builder`).
2. **Accessibility is first-class.** Semantic labels on every control; announce status changes
   (`A11y.announce`, `app/lib/core/accessibility/announce.dart`); OTP read digit-by-digit; status is
   **never colour-only** (always text + icon + a `Semantics` label); cards use `MergeSemantics`;
   touch targets ≥48dp; OS text scale is clamped to **[1.0, 1.8]** in `app/lib/app.dart`.
   `test/accessibility_test.dart` guards this with `meetsGuideline`.
3. **Privileged writes are server-only.** Clients can NOT set `role`, `verificationStatus`,
   `ratingAvg/ratingCount`, `volunteerId`, or amounts. Trips auto-start at their scheduled time
   (no OTP, M12). All state transitions (accept → end → reschedule → cancel → pay → rate → verify) go
   through **Cloud Functions** (Admin SDK) and
   are enforced by **Firestore Security Rules** (`firebase/firestore.rules`).
4. **Work milestone-by-milestone; checkpoint each.** Create a branch `master_m<n>` per milestone and
   push it. See [Milestone history](#milestone-history).
5. **Never commit secrets/config.** `firebase_options.dart`, `google-services.json`,
   `key.properties`, `*.jks`/`*.keystore`, and the root helper `*.js` scripts are **gitignored** —
   regenerate them locally, don't commit.
6. **Run the quality gates before committing:** `flutter analyze` (clean) + `flutter test` (green).
   Backend changes also need the emulator tests (see [Cookbook §D](#d-backend-tests-firestore-emulator)).

---

## Repository map
```
TravAcs/
├── AGENTS.md                      # ← you are here (project guide / agent context)
├── README.md                     # short overview (history: Supabase → Firebase)
├── TravAcs.apk                    # latest shareable debug-signed release APK (gitignored)
├── make_admin.js                  # helper: grant admin custom claim (gitignored, run via node)
├── approve_volunteer.js           # helper: approve a TravAcser for testing (gitignored)
├── enable_phone.js                # helper: enable Phone Auth + test numbers (gitignored)
├── .github/workflows/ci.yml       # CI: flutter analyze+test, and emulator rules+functions tests
│
├── app/                           # Flutter app
│   ├── pubspec.yaml               # deps + versions (v1.0.0+1, sdk ^3.7.2)
│   ├── lib/
│   │   ├── main.dart              # Firebase init + global error boundary + runApp(ProviderScope)
│   │   ├── app.dart               # MaterialApp.router + theme + textScaler clamp [1.0,1.8]
│   │   ├── firebase_options.dart  # GITIGNORED — generated by `flutterfire configure`
│   │   ├── core/
│   │   │   ├── config/            # constants.dart (₹135/hr, OTP lengths), firebase_init.dart
│   │   │   ├── error/             # failure.dart, firebase_error_mapper.dart, error_reporter.dart,
│   │   │   │                      #   stream_error.dart, error_fallback.dart, result.dart
│   │   │   ├── theme/app_theme.dart
│   │   │   ├── router/app_router.dart   # GoRouter redirect gate
│   │   │   └── accessibility/announce.dart
│   │   ├── domain/                # framework-free
│   │   │   ├── entities/          # profile, request, assignment, enums, city, pending_volunteer
│   │   │   └── repositories/      # auth_/profile_/request_/admin_ repository INTERFACES
│   │   ├── data/repositories/     # Firebase IMPLEMENTATIONS of the interfaces
│   │   └── presentation/
│   │       ├── providers/         # Riverpod providers (core/auth/profile/request/admin/messaging)
│   │       └── features/          # one folder per feature: auth, profile, requester, volunteer,
│   │                              #   admin, shell, startup, shared (+ *_controller.dart)
│   ├── android/                   # Gradle (Kotlin DSL); local.properties (gitignored) holds SDK paths
│   └── test/                      # 53 offline tests (domain, repository, provider, widget_flow,
│                                  #   error_mapper, accessibility)
│
├── firebase/                      # backend (run firebase CLI from HERE — no .firebaserc)
│   ├── firebase.json              # emulator ports (auth 9099, firestore 8080), functions config
│   ├── firestore.rules            # Security Rules (default-deny, function-only writes)
│   ├── firestore.indexes.json     # composite indexes for the watch queries
│   ├── TESTING.md                 # how to run the emulator test suites
│   ├── functions/                 # Cloud Functions (TypeScript, Node 20, firebase-functions v5)
│   │   ├── src/index.ts           # the 8 functions
│   │   └── test/index.test.ts     # 10 functions tests (firebase-functions-test + emulator)
│   └── rules-tests/test/firestore.test.js  # 25 rules tests (@firebase/rules-unit-testing)
│
└── docx/                          # documentation
    ├── design_travacs.md          # DEEP design source of truth (§0–§18)
    ├── appRequirements.md          # product requirements / user stories
    ├── EngPrinciples.md            # engineering standards
    ├── userPersona.txt             # target user
    └── m11-store-release-plan.md   # paused Play-Store release plan
```

---

## Architecture & approach

**Layered (Clean-ish) architecture:** `presentation → domain ← data`. The `domain` layer is pure
Dart (entities + repository **interfaces**); `data` implements those interfaces with Firebase SDKs;
`presentation` (Riverpod) depends only on the interfaces. This keeps the app testable offline.

- **Result type:** repositories return `FutureResult<T>` = `Future<Either<Failure, T>>` (fpdart).
  Helpers `success(v)` / `failure(f)` in `core/error/result.dart`. UI/controllers `.fold`/`.match`
  on the result; they never `try/catch` Firebase directly.
- **State management:** **Riverpod 3**. `Provider`s wire repositories; `StreamProvider`/`FutureProvider`
  expose live data; `Notifier`-based `*_controller.dart` drive actions and hold `AsyncValue<void>`.
- **Routing:** **go_router** with a Riverpod-aware redirect in `app/lib/core/router/app_router.dart`.
  Routes: `/splash`, `/auth/phone`, `/auth/otp?phone=…`, `/complete-profile`, `/home` (role shell),
  `/admin`. Redirect gate: not signed-in → `/auth/phone`; signed-in **admin claim** → `/admin`
  (skips profile gate); signed-in non-admin with **no profile** → `/complete-profile`; otherwise
  → `/home`. It listens to `authStateChangesProvider`, `isAdminProvider`, `myProfileProvider`.

### Providers (read deps) — `app/lib/presentation/providers/`
| Provider | Type | Exposes |
|---|---|---|
| `firebaseAuthProvider`, `firestoreProvider`, `firebaseReadyProvider` | Provider | Firebase singletons (overridable in tests) |
| `authStateChangesProvider` | StreamProvider | current uid (null = signed out) |
| `isAdminProvider` | FutureProvider | admin custom-claim check |
| `myProfileProvider` | FutureProvider | `MyProfile?` (null = registration incomplete) |
| `myRequestsProvider` | StreamProvider | requester's own requests |
| `myAssignmentsProvider` | StreamProvider | TravAcser's accepted trips (collectionGroup) |
| `availableRequestsProvider` | StreamProvider | open requests in the TravAcser's city, minus already-accepted (empty unless approved + city set) |
| `requestAssignmentsProvider` | StreamProvider.family | per-request assignments (requester's view) |
| `pendingVolunteersProvider` | StreamProvider | admin: volunteers awaiting verification |
| `functionsProvider` | Provider | `FirebaseFunctions.instanceFor(region: 'asia-south2')` |

### Controllers (actions) — `*_controller.dart`
`authControllerProvider` (requestOtp/verifyOtp/signOut) · `profileControllerProvider`
(save/setServiceArea/setAvailability) · `requestControllerProvider` (create/cancel/accept/reschedule/
cancelTrip/completeTrip/markPaid/markReceived/submitRating) · `adminControllerProvider` (approve/reject).

### Repositories — interface in `domain/repositories/`, impl in `data/repositories/`
- **AuthRepository** → `FirebaseAuthRepository`: Phone-OTP (`verifyPhoneNumber` bridged to a Future),
  `isAdmin()` from ID-token claims. Auth SDK only.
- **ProfileRepository** → `FirestoreProfileRepository`: single doc `profiles/{uid}`; first write sets
  immutable fields (role, verificationStatus, ratings); updates merge editable fields only.
- **RequestRepository** → `FirestoreRequestRepository`: creates `requests`, streams via queries +
  `collectionGroup('assignments')`; **all state transitions call Cloud Functions callables**.
- **AdminRepository** → `FirestoreAdminRepository`: streams pending volunteers; `setVerification`
  via callable.

### Domain entities — `app/lib/domain/entities/`
- `Request` — request details; **static** `computeEstimate(minutes, numTravAcsers)` = `round(minutes/60
  * 135 * n)`, `suggestedTravAcsers(travellers)` = `(t+1)~/2`; getters `slotsRemaining`, `isFull`.
- `Profile`/`RequesterProfile`/`VolunteerProfile`/`MyProfile`; `Assignment` (per-TravAcser trip +
  payment + ratings); `PendingVolunteer`.
- `enums.dart` — `UserRole` (requester/volunteer/admin; **labels are "User"/"TravAcser"** while wire
  values stay `requester`/`volunteer`), `RequestStatus`, `TripStatus`, `PaymentStatus`,
  `VerificationStatus`, `Gender`, `Region` (Delhi NCR + states/UTs).
- `city.dart` — curated `City` list; matching key is the **city** `wireValue`.

---

## Backend (Firebase)

### Firestore data model
| Path | Written by | Key fields |
|---|---|---|
| `profiles/{uid}` | client (editable) + functions (protected) | role, fullName, gender?, dateOfBirth?, phone?, isActive, serviceArea, serviceCity, ratingAvg, ratingCount; **volunteer:** address?, verificationStatus, verifiedBy?, rejectionReason?; **requester:** homeLocationText? |
| `requests/{id}` | client create; functions transition | requesterId, status, serviceArea, serviceCity, numTravellers, numTravAcsers, acceptedCount, genderPreference, scheduledDate, startTime, **scheduledStartAt** (auto-start anchor), expectedDurationMinutes, meetingPoint, destination, estimatedAmountInr, … |
| `requests/{id}/assignments/{volunteerId}` | **functions only** | contact pair, denormalized summary (incl. genderPreference, scheduledStartAt), tripStatus (assigned/started/completed/closed/cancelled), startedAt/endedAt, durationMinutes, amountInr, paymentStatus, requesterPaidAt/travAcserReceivedAt, ratings |
| `devices/{uid}/tokens/{token}` | client (self) | FCM tokens |
| `ratings/{id}`, `trips/{id}` | (rules present; ratings are primarily stored on the assignment) | audit/future use |

> **No OTP / `secrets` subcollection** since M12 — trips auto-start at `scheduledStartAt`.

**Rules helpers** (`firebase/firestore.rules`): `isSignedIn()`, `isAdmin()` (`token.admin==true`),
`isApprovedVolunteer()` (role volunteer + approved + active), `myCity()`. Requests are **region-scoped**
(an approved TravAcser sees only `broadcast` requests where `serviceCity == myCity()`). The requester
can only **cancel before any accept** (client-side); `assignments`/`trips` are **function-only writes**.
A **collection-group** rule (`match /{path=**}/assignments/{vid}`) lets a TravAcser list their own
assignments — it gates on `resource.data.volunteerId == request.auth.uid` (a doc-id check errors during
a list, since the path wildcard is null then).

### Cloud Functions — `firebase/functions/src/index.ts` (region `asia-south2`)
Trips **auto-start at `scheduledStartAt`** (time-derived; no OTP, no scheduled function).
| Function | Type | What it does / key guards |
|---|---|---|
| `onRequestCreated` | Firestore onCreate `requests/{id}` | Fan-out FCM to approved+active TravAcsers in the same city; prunes dead tokens. |
| `acceptRequest` | onCall | FCFS slot fill in a transaction: must be approved+active TravAcser, request `broadcast` + same city + not full + not already accepted; creates the assignment (denormalizing genderPreference + scheduledStartAt); auto-transitions request to `assigned` when full. **No OTP.** |
| `completeTrip` | onCall | End a trip — caller = TravAcser **or** requester; only valid once `now >= scheduledStartAt`; bills from `scheduledStartAt`; marks `completed`; marks the request completed when no active assignment remains. |
| `rescheduleTrip` | onCall | **Requester-only**, before start; updates the request + all assignments' schedule (date/startTime/scheduledStartAt). |
| `cancelTrip` | onCall | Either party. Requester → cancels the whole request + assignments. TravAcser → cancels their assignment, decrements `acceptedCount`, reopens the request to `broadcast`. |
| `markPaid` / `markReceived` | onCall | Two-sided payment state machine (`pending`→`awaiting_other`→`confirmed`). `markPaid` is requester-only. |
| `submitRating` | onCall | Mutual 1–5 rating after `completed`; updates the ratee's rolling `ratingAvg`/`ratingCount`; blocks duplicates. |
| `setVerification` | onCall | **Admin-claim only**; approves/rejects a TravAcser; pushes the result. |

---

## Milestone history
Branch-per-milestone; all pushed to `origin`. `master_old` preserves the original **Supabase**
implementation (the backend was migrated to Firebase early for India phone-OTP without DLT/SMS-gateway
friction).

| Milestone | Shipped | Checkpoint |
|---|---|---|
| M0–M2 | Firebase foundations, Firestore model + Rules + Phone Auth, profiles/registration + role shell | (folded into early history) |
| M3 | Requests + broadcast + FCM fan-out (`onRequestCreated`); Blaze plan enabled | `master_m3` |
| M4 | FCFS slot-filling accept (transaction) + contact exchange + per-TravAcser OTP | `master_m4` |
| M5 | Trip start (OTP) → complete → per-TravAcser billing | `master_m5` |
| M6 | Two-sided payment + mutual ratings | `master_m6` |
| M7 | Admin verification (`setVerification` + admin screen) | `master_m7` |
| **M8** | **Graceful error handling** — Failure taxonomy, mapper, stream mapping, global boundary, Crashlytics; users never see raw errors | `master_m8` |
| **M9** | **Accessibility pass** — text-scale clamp, status-not-colour-only, MergeSemantics, announcements, `meetsGuideline` tests | `master_m9` |
| **M10** | **Automated tests** — M10a 53 offline tests; M10b 25 rules + 10 functions emulator tests; M10c GitHub Actions CI | `master_m10`, `master_m10a/b/c` |
| **M11** | **Store-release prep (Android)** — **PLANNED, PAUSED.** See `docx/m11-store-release-plan.md`. | — |
| **M12** | **Feature-completion / gap-fill** — fixed the collection-group rules bug (My Trips), built real History tabs (replacing placeholders), made the active-trip lifecycle first-class, **removed OTP** (trips auto-start at `scheduledStartAt`; either party ends), added **reschedule** (User) + **cancel** (both sides), and redesigned the request form (gender-preference dropdown, TravAcser slider, dropped landmark + male/female split). | `master_m12` |

> Note: `docx/design_travacs.md` §17 uses an older roadmap numbering; the **branches above are the
> authoritative record** of what actually shipped.
>
> M12 removed `startTrip`/OTP entirely (trips auto-start by time). The M12 rules + functions are
> deployed to `travacs-dev` (`asia-south2`).

---

## Environment & toolchain (this dev machine)
Windows 11 **ARM64**, corporate-managed (**no admin**; MSI installers blocked). Everything is a
portable ZIP install. Shell is **PowerShell**.

| Tool | Path / value |
|---|---|
| Flutter SDK | `C:\Users\sauprasad\develop\flutter` (`flutter` is on PATH) |
| Dart SDK | bundled with Flutter; `environment: sdk: ^3.7.2` |
| Portable JDK 17 | `C:\Users\sauprasad\dev-tools\jdk17\jdk-17.0.19+10` |
| Android SDK | `C:\Users\sauprasad\dev-tools\android-sdk` |
| adb | `C:\Users\sauprasad\dev-tools\android-sdk\platform-tools\adb.exe` |
| Node / npm | Node 22 / npm 10.9 on PATH |
| Firebase CLI | global `firebase` (v15); logged in as `saurabhprasad20@gmail.com` |
| Test phone | `M2010J19CI` (Xiaomi/MIUI, Android 12), adb id **`171a26b21220`** |

Key build values (from `app/android/app/build.gradle.kts` + `settings.gradle.kts`):
`applicationId`/`namespace` = **`com.travacs.travacs`**, **minSdk 23**, **ndkVersion 27.0.12077973**,
**Kotlin 2.2.0**, **AGP 8.7.0**. Firebase project **`travacs-dev`** (number `376835689559`), functions
**Node 20**, region **`asia-south2`**.

**Gotchas to know:**
- **Gitignored config must be regenerated** before building (see below) — `firebase_options.dart`
  and `google-services.json` are not in the repo.
- **Firebase emulator needs Java**, but the global `firebase-tools` v15 requires **Java 21+** while
  this machine has **JDK 17**. Workaround: pin **`npx -y firebase-tools@13`** for emulator commands
  (it accepts Java 17). CI uses JDK 21 + latest firebase-tools instead.
- **MIUI** blocks `adb install` unless "Install via USB" is enabled (needs a Mi account); tap-installing
  the APK from a file also works. `install -r` worked in the last session.
- **Long commands run in the foreground** — background shell commands get killed on this machine.

---

## Command cookbook
All commands are **PowerShell**. Working directory matters — each block says where to run it.
Where a command touches the Android build or the emulator, set `JAVA_HOME` first (shown inline).

### A. First-time setup (on a fresh clone)
```powershell
# 1) Firebase config (writes the gitignored app/lib/firebase_options.dart + android google-services.json)
#    Requires: `firebase login` and the FlutterFire CLI (`dart pub global activate flutterfire_cli`).
cd C:\Users\sauprasad\travacs\TravAcs\app
flutterfire configure --project=travacs-dev

# 2) Flutter deps
flutter pub get

# 3) Backend deps (only needed to run the emulator test suites)
npm install --prefix C:\Users\sauprasad\travacs\TravAcs\firebase\functions
npm install --prefix C:\Users\sauprasad\travacs\TravAcs\firebase\rules-tests
```

### B. Build & run on the phone
```powershell
$env:JAVA_HOME = "C:\Users\sauprasad\dev-tools\jdk17\jdk-17.0.19+10"
$env:PATH      = "$env:JAVA_HOME\bin;$env:PATH"
cd C:\Users\sauprasad\travacs\TravAcs\app

# Build a release APK (currently DEBUG-signed — release signing is M11)
flutter build apk --release        # -> build\app\outputs\flutter-apk\app-release.apk (~50 MB)

# Refresh the shareable copy at repo root
Copy-Item build\app\outputs\flutter-apk\app-release.apk ..\TravAcs.apk -Force

# Install + launch on the connected phone
$adb = "C:\Users\sauprasad\dev-tools\android-sdk\platform-tools\adb.exe"
& $adb -s 171a26b21220 install -r ..\TravAcs.apk
& $adb -s 171a26b21220 shell monkey -p com.travacs.travacs -c android.intent.category.LAUNCHER 1

# OR, for a dev session that builds+installs+launches+attaches:
flutter run -d 171a26b21220
```
Useful: `flutter devices` (list connected devices), `& $adb devices` (raw adb list).

### C. Quality gates (offline, fast)
```powershell
cd C:\Users\sauprasad\travacs\TravAcs\app
flutter analyze        # must be clean (no issues)
flutter test           # 53 tests: domain, repository, provider, widget_flow, error_mapper, accessibility
flutter test test/domain_test.dart   # run a single file
```

### D. Backend tests (Firestore emulator)
Run from `firebase/`. These spin up the Firestore emulator, run the suite, and shut it down.
```powershell
$env:JAVA_HOME = "C:\Users\sauprasad\dev-tools\jdk17\jdk-17.0.19+10"
$env:PATH      = "$env:JAVA_HOME\bin;$env:PATH"
cd C:\Users\sauprasad\travacs\TravAcs\firebase

# Security Rules tests (25)
npx -y firebase-tools@13 emulators:exec --only firestore --project demo-travacs `
  "npm --prefix rules-tests test"

# Cloud Functions tests (10)
npx -y firebase-tools@13 emulators:exec --only firestore --project demo-travacs `
  "npm --prefix functions test"
```
(`--project demo-travacs` uses a demo project so no real credentials are touched. The
`firebase-tools@13` pin is the JDK-17 workaround — see Gotchas. Full notes in `firebase/TESTING.md`.)

### E. Build & deploy the backend (production = `travacs-dev`)
Run from `firebase/`. Functions require the **Blaze** billing plan. There is no `.firebaserc`, so
always pass `--project travacs-dev`.
```powershell
cd C:\Users\sauprasad\travacs\TravAcs\firebase

# Compile the functions (also runs automatically as a predeploy step)
npm --prefix functions run build

firebase deploy --only functions --project travacs-dev            # all functions
firebase deploy --only functions:acceptRequest --project travacs-dev  # one function
firebase deploy --only firestore:rules --project travacs-dev      # security rules
firebase deploy --only firestore --project travacs-dev            # rules + indexes
```

### F. Admin / setup helpers (root, gitignored, run with Node)
These read your existing `firebase login` session. For **local testing/bootstrap only**.
```powershell
cd C:\Users\sauprasad\travacs\TravAcs
node make_admin.js +9198XXXXXXXX   # grant the `admin` custom claim (E.164 phone); user must re-login
node approve_volunteer.js          # approve the hardcoded test TravAcser (+918178796516)
node enable_phone.js               # enable Phone Auth + register test numbers
```
Test phone numbers (Firebase test OTP): `+918979515501` and `+918178796516`, code **`123456`**.

### G. Git / checkpoint workflow
```powershell
cd C:\Users\sauprasad\travacs\TravAcs
# work on master; at the end of a milestone, checkpoint it:
git branch master_m<n>
git push -u origin master_m<n>
git push origin master
```
Commit messages end with a trailer:
```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

---

## CI — `.github/workflows/ci.yml`
Runs on every push + PR. Two jobs:
- **flutter-tests** — writes a stub `firebase_options.dart` (the real one is gitignored), then
  `flutter pub get` → `flutter analyze` → `flutter test`.
- **backend-tests** — sets up **JDK 21** + latest `firebase-tools`, `npm ci`, then `emulators:exec`
  for the rules (25) and functions (10) suites.

"Green" = both jobs pass. There's no `gh` CLI on the dev machine; check runs via the GitHub web UI or
the public Actions API.

---

## Known gaps & next work
- **M11 (Play-Store release) — paused.** Critical blockers documented in
  `docx/m11-store-release-plan.md`: (a) release build still uses the **debug signing key**;
  (b) **`INTERNET` and `POST_NOTIFICATIONS` are only in the debug/profile manifests, not the main
  `AndroidManifest.xml`** — a *release* build would have **no network** and no FCM on Android 13+.
  Also: default launcher icon, no R8/minify, Crashlytics Gradle plugin not applied.
- **Deferred on-device passes:** the M8 error-handling runtime check (airplane mode, full-slot
  accept, denied permission, forced crash → friendly fallback) and the M9 TalkBack end-to-end pass
  were never run on a physical device. After M12, also re-verify the full trip flow on-device
  (create → accept → auto-start → end → pay → rate; reschedule; cancel from both sides).
- **Functions runtime:** Node 20 is deprecated (decommission 2026-10-30) — bump `engines.node` to 22
  and redeploy when convenient.
- **Next planned step:** continue user + functions testing of the M12 flow, then iterate; M11
  store-release remains paused.

---

## Where to look next
| Topic | File |
|---|---|
| Deep system design (§0–§18) | `docx/design_travacs.md` |
| Product requirements / user stories | `docx/appRequirements.md` |
| Engineering standards | `docx/EngPrinciples.md` |
| Target user | `docx/userPersona.txt` |
| Backend test how-to | `firebase/TESTING.md` |
| Paused Play-Store release plan | `docx/m11-store-release-plan.md` |
| Error-handling taxonomy | `app/lib/core/error/` |
| Routing gate | `app/lib/core/router/app_router.dart` |
| Security rules | `firebase/firestore.rules` |
| Cloud Functions | `firebase/functions/src/index.ts` |
