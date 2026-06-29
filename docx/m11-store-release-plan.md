# M11 — Store-Release Prep (Android / Google Play) — PLANNED, NOT YET STARTED

> Status: **documented, paused.** We will run user + Cloud Functions testing first,
> then do an improvement cycle, and only then execute M11. No M11 code changes have
> been made. This file is the executable plan to resume from.
>
> Scope note: **Android only** (no Mac available for iOS). Store-console submission,
> screenshots, feature graphic, and privacy-policy hosting are manual / outside the repo.

---

## Decisions still open (ask before executing M11a)
1. **Keystore** — generate the upload keystore locally now (keytool via portable JDK,
   gitignored `key.properties` + strong password surfaced for backup) **vs** user provides
   **vs** defer signing. *Recommended: generate locally now* (Play App Signing makes the
   upload key recoverable).
2. **App icon** — generate a clean branded adaptive icon (image pkg + flutter_launcher_icons)
   **vs** user provides a 1024×1024 logo **vs** keep default Flutter icon.
   *Recommended: generate a clean branded icon.*
3. **Cloud Functions runtime** — bump Node 20 → 22 (Node 20 deprecated; decommission
   **2026-10-30**) and redeploy **vs** bump in repo only **vs** leave as-is.
   *Recommended: bump + redeploy* (low risk on firebase-functions v5).

---

## Release-readiness audit (as of master_m10, commit 8b1a1da)

### ❌ Critical blockers
- **Release signing uses DEBUG keys.** `app/android/app/build.gradle.kts:45` —
  `buildTypes.release` uses `signingConfigs.getByName("debug")`. No `key.properties`,
  no keystore. Play will not accept a debug-signed AAB.
- **`INTERNET` permission is only in the debug/profile manifests, not main.** A *release*
  build merges only `app/android/app/src/main/AndroidManifest.xml`, so the released app
  would have **no network** → Firebase fails. Also **`POST_NOTIFICATIONS` is missing**
  (required for FCM on Android 13+).

### ⚠ High priority
- **Default Flutter launcher icon** still in `res/mipmap-*/ic_launcher.png` (placeholder).
- **Crashlytics Gradle plugin not applied** (`com.google.firebase.crashlytics`) → release
  crashes won't deobfuscate / no mapping upload.
- **No R8/minify** (`isMinifyEnabled`/`isShrinkResources` unset; no `proguard-rules.pro`).

### ⚠ Medium
- `android:label="travacs"` (lowercase, generic) → set to **"TravAcs"**.
- No splash branding beyond white (`launch_background.xml`). Optional.

### ✓ Already fine
- `applicationId` / `namespace` = `com.travacs.travacs` (not `com.example.*`).
- `minSdk 23`, `ndkVersion 27.0.12077973`, Kotlin/Gradle toolchain solid.
- `version: 1.0.0+1` (pubspec) consistent.
- `google-services.json` is gitignored at repo root (`.gitignore:9`) — verify it's untracked
  (`git ls-files --error-unmatch app/android/app/google-services.json` should fail).
- `key.properties`, `*.jks`, `*.keystore` already gitignored (`app/android/.gitignore:19-20`).

---

## M11a — Release hardening (engineering; build + verify a signed AAB)

### 1. Branding + icon
- `app/android/app/src/main/AndroidManifest.xml`: `android:label="TravAcs"`.
- Add dev dep `flutter_launcher_icons`; add config to `pubspec.yaml`:
  ```yaml
  flutter_launcher_icons:
    android: true
    ios: false
    image_path: "assets/icon/travacs_icon.png"   # 1024x1024
    adaptive_icon_background: "#0B5FFF"           # brand blue (matches AppTheme seed)
    adaptive_icon_foreground: "assets/icon/travacs_icon_fg.png"
  ```
  Source icon: either user-provided logo, or generate a 1024×1024 PNG (brand-blue
  rounded square + clear glyph) with the `image` package in a one-off `tool/gen_icon.dart`.
  Then `dart run flutter_launcher_icons`.

### 2. Manifest permissions (BLOCKER fix)
In `app/android/app/src/main/AndroidManifest.xml`, above `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```
(`POST_NOTIFICATIONS` is runtime-requested on Android 13+; FCM permission flow already
exists in `firebase_messaging_repository.dart` registerToken.)

### 3. Release signing
- Generate (portable JDK):
  ```sh
  "C:\Users\sauprasad\dev-tools\jdk17\jdk-17.0.19+10\bin\keytool" -genkeypair -v \
    -keystore app/android/travacs-upload.jks -keyalg RSA -keysize 4096 -validity 10950 \
    -alias travacs-upload
  ```
- `app/android/key.properties` (GITIGNORED — never commit):
  ```
  storeFile=../travacs-upload.jks
  storePassword=<...>
  keyPassword=<...>
  keyAlias=travacs-upload
  ```
- `app/android/app/build.gradle.kts` — load props and wire `signingConfigs.release`,
  set `buildTypes.release.signingConfig = signingConfigs.getByName("release")`.
  Keystore + password must be **backed up by the user** (lost upload key → re-enroll via
  Play App Signing).

### 4. R8 + ProGuard
- `build.gradle.kts` release block: `isMinifyEnabled = true`, `isShrinkResources = true`,
  `proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")`.
- `app/android/app/proguard-rules.pro` — keep rules for Firebase, GMS, Crashlytics, Flutter.
- **Verify the AAB builds** (R8 can strip reflectively-used classes — watch for runtime issues).

### 5. Crashlytics Gradle plugin
- Apply `id("com.google.firebase.crashlytics")` in `app/android/app/build.gradle.kts` and add
  the classpath/plugin to `app/android/settings.gradle.kts` (or the plugins block) per the
  FlutterFire Crashlytics setup. Confirms mapping upload on release builds.

### 6. Build + verify
- `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.
- Verify signer: `jarsigner -verify -verbose -certs app-release.aab` (or `bundletool`),
  confirm it's the `travacs-upload` cert, not the debug cert.

### 7. (Optional, per decision) Functions runtime bump
- `firebase/functions/package.json` `"engines": {"node": "22"}`; `npm run build` + emulator
  tests (M10b) green; `firebase deploy --only functions --project travacs-dev`.

---

## M11b — Release docs (repo)
- `docx/privacy-policy.md` — data collected: phone number (auth), profile (name, gender,
  DOB optional, service city, address/home text), FCM device tokens, ratings; Crashlytics
  diagnostics. No Aadhaar. Sharing: counterpart contact shared only after assignment.
- `docx/store-listing.md` — short description, full description, and the **Play Data-Safety
  mapping** (collected/shared/purpose per field).
- `docx/release-checklist.md` — keystore backup, enable Play App Signing, internal-testing
  track, screenshots captured on device 171a26b21220, feature graphic, content rating,
  target-audience, privacy-policy URL.

---

## Deferred items to fold into the next improvement cycle
- **On-device M8 runtime pass:** airplane-mode → friendly "No internet"; wrong trip OTP;
  accept an already-full request; non-admin hitting an admin path; forced crash → friendly
  fallback (not red/grey screen). Confirm Crashlytics receives the non-fatals.
- **On-device M9 TalkBack pass:** full request→accept→trip→pay→rate by voice; confirm every
  status spoken, no unlabeled control, no dialog focus trap, OS text at 200% no clipping.
- **Already shipped:** `startTrip` OTP rate-limit fix is deployed to `travacs-dev`
  (asia-south2) as of the M10b cycle.

## Resume pointer
Start by re-reading this file, then re-ask the 3 open decisions, then execute M11a in order
(branding → manifest → signing → R8 → crashlytics → build/verify), checkpoint `master_m11a`,
then M11b, checkpoint `master_m11b`.
