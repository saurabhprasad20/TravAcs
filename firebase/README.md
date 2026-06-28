# TravAcs — Firebase backend

Version-controlled Firebase config for TravAcs (see `../docx/design_travacs.md`).

## Contents
| File | Purpose |
|------|---------|
| `firestore.rules` | Security Rules — the authorization layer (design §5.2). Default-deny; protected fields locked; the single guarded FCFS "accept" transition. |
| `firestore.indexes.json` | Composite indexes for the request feeds. |
| `firebase.json` | Firestore + Emulator Suite config. |
| `functions/` | Cloud Functions (added in M3: FCM fan-out, trip OTP, payment, setVerification). |

## One-time project setup
1. Create a Firebase project (e.g. `travacs-dev`) at https://console.firebase.google.com.
2. **Authentication → Sign-in method → Phone** → enable. (Phone Auth sends SMS via
   Google — works for +91 with no DLT registration.)
3. **Firestore Database** → create (production mode).
4. Add an **Android app** with package `com.travacs.travacs`, and register your
   **SHA-1** (and SHA-256) fingerprints — required for Phone Auth on Android:
   ```
   cd ../app/android && ./gradlew signingReport      # copy the debug SHA-1
   ```
   Paste it in Firebase console → Project settings → your Android app → Add fingerprint.

## Wire the Flutter app to the project
```
dart pub global activate flutterfire_cli
cd ../app
flutterfire configure --project=<your-firebase-project-id>
```
This generates `app/lib/firebase_options.dart` and `android/app/google-services.json`
(replacing the placeholder). Then `flutter run` / build.

## Deploy rules & indexes (needs Firebase CLI; run yourself)
```
npm i -g firebase-tools     # or: npx firebase-tools
firebase login
firebase deploy --only firestore --project <your-firebase-project-id>
```

## Local testing (no cost) — Emulator Suite
```
firebase emulators:start
```
Used for rules tests and integration tests (design §15).

## Bootstrapping the first admin
Admin is a custom claim (`admin: true`), set via the Admin SDK (a one-off
`setAdminClaim` script / Cloud Function in M7). The custom admin approve/reject
page also lands in M7.

## Plan note
Auth + Firestore + profiles run on the **free Spark plan**. **Cloud Functions
(M3+: FCM fan-out, trip OTP, payment, setVerification) require the Blaze plan.**
