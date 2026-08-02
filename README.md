# TravAcs

An accessibility-first, cross-platform (Flutter) app that pairs visually-impaired
**Users** ("requesters") with verified **TravAcsers** ("volunteers") for short,
paid, in-person travel/mobility assistance in India.

- **Agent & developer guide (start here):** [`AGENTS.md`](AGENTS.md)
- **Behavior baseline (regression reference):** [`docx/behavior_baseline.md`](docx/behavior_baseline.md)
- **Full design (source of truth):** [`docx/design_travacs.md`](docx/design_travacs.md)
- **Product & requirements:** [`docx/appRequirements.md`](docx/appRequirements.md)
- **Engineering principles:** [`docx/EngPrinciples.md`](docx/EngPrinciples.md)

## Stack
Flutter (Dart) + **Riverpod 3** front end — layered (Clean-ish)
`presentation → domain ← data`, Repository pattern, results as
`Future<Either<Failure, T>>` (fpdart) — on a **Firebase** back end:
**Phone-OTP Auth, Cloud Firestore, Cloud Functions (TypeScript, Node 20),
FCM, Crashlytics**. In-app payments via **Razorpay** (live).

- Firebase project: **`travacs-dev`** · callable functions region
  **`asia-south2`** (scheduled functions in `asia-south1`).
- Android: `applicationId`/`namespace` **`com.travacs.travacs`**, **minSdk 23**.

> **Backend history:** v1 was first built on Supabase, then migrated to Firebase
> to remove backend friction — chiefly **phone-OTP for +91 numbers** (no DLT /
> SMS-gateway). The Supabase version is preserved on the **`master_old`** branch.

## Repository layout
```
app/        Flutter application (lib/ + 100+ offline tests in test/)
firebase/   Firestore rules + indexes + Cloud Functions + emulator test suites
docx/       Design, requirements, engineering principles, behavior baseline
AGENTS.md   Single entry point / agent context (fuller than this file)
```

## What it does
- **Phone-OTP login** → one-time **complete-profile** → role-based tab shell
  (User / TravAcser) with a navigation **Drawer** (Contact, About, Terms,
  Privacy, Sign out).
- **Users** create travel-assistance **requests** (city, schedule, number of
  travellers, TravAcsers needed, gender preference, meeting point, destination).
- Requests **broadcast** to approved TravAcsers in the same city (FCM fan-out).
  A late-approved TravAcser still sees any request that is still open + upcoming.
- **TravAcsers accept** on a first-come-first-served basis (server transaction).
- **Trip lifecycle:** start (TravAcser validates the User's deterministic
  **offline start-code**) → end → **two-sided payment** (Razorpay) → **mutual
  1–5 rating**. Users can **reschedule/cancel**; both sides can cancel.
- **Admin** verifies (approves/rejects) TravAcsers and views active trips.
- Billing: **₹149/hr** per TravAcser serving 1 traveller, **₹210/hr** serving 2,
  **+ ₹100 travel** per TravAcser, min 1-hour bill. **Test phase: only ₹1 is
  collected at checkout.**

## Golden rules (do NOT regress)
1. **No raw errors to users** — everything flows through the sealed `Failure`
   taxonomy + `mapFirebaseError()`; raw detail only goes to Crashlytics.
2. **Accessibility is first-class** — semantic labels on every control, status is
   never colour-only, announcements on state change, text scale clamped to
   `[1.0, 1.8]`, touch targets ≥48dp.
3. **Privileged writes are server-only** — clients can't set role, verification,
   ratings, amounts, or assignments; all state transitions go through Cloud
   Functions and are enforced by Firestore Security Rules.
See [`AGENTS.md`](AGENTS.md) for the full list.

## Milestone status
| Milestone | Status |
|-----------|--------|
| M0–M2 Firebase foundations, model + rules + phone-OTP, profiles + role shell | ✅ done |
| M3 Requests + broadcast + FCM fan-out | ✅ done |
| M4 FCFS accept + contact exchange · M5 Trip start/complete + billing | ✅ done |
| M6 Two-sided payment · M7 Admin verification | ✅ done |
| M8 Graceful error handling · M9 Accessibility pass | ✅ done |
| M10 Automated tests (offline + emulator) + CI | ✅ done |
| **M11 Play-Store release prep (Android)** | ⏸️ **paused** — see `docx/m11-store-release-plan.md` |
| M12 Feature-completion / lifecycle gap-fill | ✅ done |
| M13 App menu (Drawer + info screens) · M14 A11y label/control fixes | ✅ done |

Beyond the numbered milestones: **in-app Razorpay payment (live)**, **offline
start-code** trip start, one-trip-per-day guard, request auto-expiry,
reschedule confirm/cancel, started-trip lock, gender-matched broadcast, and
admin dashboards. Each milestone is checkpointed as branch `master_m<n>`.

## Getting started

### 1. Wire the Firebase config (one-time — gitignored, the app won't build without it)
```powershell
# Requires: `firebase login` + `dart pub global activate flutterfire_cli`
cd app
flutterfire configure --project=travacs-dev
# writes app/lib/firebase_options.dart + android/app/google-services.json
flutter pub get
```

### 2. Run on a device
```powershell
cd app
flutter run                              # to a connected device/emulator
flutter build apk --release              # shareable APK (currently debug-signed)
```

### Quality gates (offline, fast)
```powershell
cd app
flutter analyze        # must be clean
flutter test           # 104 offline tests
```

### Backend tests (Firestore emulator; needs Java)
Run from `firebase/`. On JDK 17 pin firebase-tools@13 (see AGENTS.md):
```powershell
cd firebase
npx -y firebase-tools@13 emulators:exec --only firestore --project demo-travacs "npm --prefix rules-tests test"   # 39 rules tests
npx -y firebase-tools@13 emulators:exec --only firestore --project demo-travacs "npm --prefix functions test"     # 54 functions tests
```

### Build + deploy the backend (there is no `.firebaserc` — always pass `--project`)
```powershell
cd firebase
npm --prefix functions run build
firebase deploy --only functions --project travacs-dev
firebase deploy --only firestore:rules --project travacs-dev
```

## Notes
- **No SMS gateway / DLT** — Firebase Phone Auth handles OTP for India.
  Test numbers: `+918979515501`, `+918178796516`, code `123456`.
- **Plan:** Cloud Functions require the **Blaze** billing plan.
- **Secrets are never committed** — `firebase_options.dart`,
  `google-services.json`, keystores, and Razorpay keys (Firebase Secret Manager:
  `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET`) are all kept out of the repo.
- **CI** (`.github/workflows/ci.yml`): `flutter analyze` + `flutter test`, plus
  the emulator rules + functions suites. Both jobs must be green.
