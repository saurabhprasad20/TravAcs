# Backend tests (M10b) — Firestore Security Rules & Cloud Functions

These run against the **Firebase Emulator Suite** (Firestore emulator only — the
Cloud Functions are invoked in-process via `firebase-functions-test`).

## Prerequisites
- **Node 20+** and **Java 17+** (the Firestore emulator is a Java process).
- This repo's portable JDK lives at
  `C:\Users\sauprasad\dev-tools\jdk17\jdk-17.0.19+10` (Windows). The global
  `firebase-tools` (v15) requires **Java 21+**, so the commands below pin
  **`firebase-tools@13`** via `npx`, which is happy with Java 17.

## One-time install
```sh
npm --prefix rules-tests install
npm --prefix functions  install
```

## Run (PowerShell, from the `firebase/` directory)
```powershell
$env:JAVA_HOME = "C:\Users\sauprasad\dev-tools\jdk17\jdk-17.0.19+10"
$env:PATH      = "$env:JAVA_HOME\bin;$env:PATH"

# Security Rules tests (25)
npx -y firebase-tools@13 emulators:exec --only firestore --project demo-travacs `
  "npm --prefix rules-tests test"

# Cloud Functions tests (10)
npx -y firebase-tools@13 emulators:exec --only firestore --project demo-travacs `
  "npm --prefix functions test"
```

`emulators:exec` starts the emulator, sets `FIRESTORE_EMULATOR_HOST` +
`GCLOUD_PROJECT`, runs the script, then shuts the emulator down. The
`demo-` project prefix means no real credentials are touched.

## What's covered
- **`rules-tests/test/firestore.test.js`** — the access matrix from
  `firestore.rules`: self-scoped profile reads, region-scoped request reads,
  protected-field rejection (role / verification / ratings), function-only
  `assignments` writes, request-create constraints (forged `acceptedCount`,
  out-of-range counts), ratings server-only, device-token privacy.
- **`functions/test/index.test.ts`** — `acceptRequest` (FCFS slot fill +
  over-subscription + not-approved), `startTrip` (TravAcser-only start-code
  flip, time guard, User rejected), `completeTrip` (billing from the recorded
  `startedAt`, must be started), two-sided payment state machine,
  `verifyRazorpayPayment`, `submitRating` (rolling average + duplicate block),
  `setVerification` / `logManualTrip` (admin gate).
