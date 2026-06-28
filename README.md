# TravAcs

A cross-platform (Flutter) app connecting visually impaired users ("Requesters")
with verified volunteers ("TravAcsers") for short, paid travel/mobility
assistance. Accessibility-first.

- **Product & requirements:** `docx/appRequirements.md`
- **Engineering principles:** `docx/EngPrinciples.md`
- **Full design (the source of truth):** `docx/design_travacs.md`

## Stack
Flutter + Riverpod (layered: data / domain / presentation, Repository pattern) ·
**Firebase** (Phone Auth, Cloud Firestore, Cloud Functions, Storage, FCM, App Check).

> **Backend history:** v1 was first built on Supabase; we migrated to Firebase to
> remove backend friction — chiefly **phone-OTP for +91 numbers** (Firebase sends
> SMS via Google with **no DLT**). The Supabase version is preserved on the
> **`master_old`** git branch.

## Repository layout
```
app/        Flutter application
firebase/   Firestore rules + indexes + (later) Cloud Functions — see firebase/README.md
admin/      Admin web page (lands in M7)
docx/       Design & requirements docs
```

## Implementation status (see design §17)
| Milestone | Status |
|-----------|--------|
| M0 Deps swap + scaffolding (Firebase) | ✅ code done |
| M1 Firestore rules + phone-OTP auth | ✅ code done |
| M2 Firestore profiles + role shell | ✅ code done |
| (gate) `flutterfire configure` + build on device | ⏳ needs Firebase project |
| M3 Requests + broadcast + FCM | ⬜ planned |
| M4 FCFS accept · M5 Trip OTP/billing · M6 Two-sided payment · M7 Admin · M8 Hardening | ⬜ planned |

What works (once configured): phone-OTP login → one-time complete-profile →
role-based bottom-tab shell. Feature tabs are accessible placeholders; the
Profile tab is fully functional.

## Getting started

### 1. Create + wire the Firebase project (one-time)
See [`firebase/README.md`](firebase/README.md). In short:
- Create a Firebase project; enable **Phone** auth; create **Firestore**.
- Add an Android app (`com.travacs.travacs`) and register your **SHA-1**.
- Generate config:
  ```powershell
  dart pub global activate flutterfire_cli
  cd app
  flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
  ```
  This writes `app/lib/firebase_options.dart` + `android/app/google-services.json`.
- Deploy rules: `firebase deploy --only firestore` (from `firebase/`).

### 2. Run the app
```powershell
cd app
flutter pub get
flutter run        # to a connected device/emulator
```
Until `flutterfire configure` is run, the app shows a "Firebase not configured" screen.

### Quality gates
```powershell
cd app
flutter analyze    # currently clean
flutter test
```

## Notes
- **No SMS gateway / DLT needed** — Firebase Phone Auth handles OTP for India.
- **Plan:** Auth + Firestore + profiles run on the free **Spark** plan; **Cloud
  Functions (M3+) need the Blaze plan.**
- **First admin:** set the `admin` custom claim (M7).
