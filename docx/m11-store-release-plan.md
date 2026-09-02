# M11 — Google Play release readiness

> Status on September 2, 2026: **Android engineering complete locally; Play Console and policy
> prerequisites remain.** The current signed bundle is `TravAcs-release.aab` at the repository root
> (gitignored).

## Completed engineering

- Android `compileSdk` and `targetSdk` are 36; minimum SDK remains 23.
- Gradle 8.13, Android Gradle Plugin 8.13.2, and Kotlin 2.3.21 are configured.
- `INTERNET` and `POST_NOTIFICATIONS` are in the main release manifest.
- The application label is `TravAcs`.
- Branded legacy and adaptive launcher icons are generated from the supplied logo.
- Release builds use a dedicated upload key and fail instead of falling back to debug signing when
  `android/key.properties` is unavailable.
- R8 code shrinking and resource shrinking are enabled with Razorpay/WebView compatibility rules.
- The Firebase Crashlytics Gradle plugin injects the mapping ID and wires the release mapping upload.
- The app includes accessible links for the hosted Terms and Privacy documents while retaining the
  bundled copies for offline reading.
- The upload key SHA-1 and SHA-256 are registered with Firebase Android app
  `1:376835689559:android:168901aad38debf4f42712`.

## Current verified artifact

- File: `app/build/app/outputs/bundle/release/app-release.aab`
- Shareable copy: `TravAcs-release.aab`
- Size: 29,361,994 bytes
- SHA-256: `588D11AEE18CF3141ED564CF988833BE6AAC6FD56C81B392C5F1F57EE3B32912`
- Package: `com.travacs.travacs`
- Version: `1.0.0+1`
- Target API: 36
- Upload certificate SHA-1:
  `42:1F:5A:FB:42:7E:F9:3E:B7:21:16:9B:63:7C:35:6E:AF:A5:C3:7C`
- Upload certificate SHA-256:
  `54:A4:8E:81:82:8F:C8:D3:3E:D7:CB:F1:AF:DF:D7:0E:A2:4A:3F:52:F5:67:C7:9A:E1:01:F0:3D:07:CA:25:C3`
- R8 mapping: `app/build/app/outputs/mapping/release/mapping.txt`

The keystore, `key.properties`, passwords, APKs, and AABs are intentionally gitignored. Keep the
upload-key backup outside the repository and protect it as a release credential.

## Blocking external and product work

1. **Legal pages:** the supplied URLs currently return HTTP 404:
   - `https://travacs.in/termsandconditions`
   - `https://travacs.in/privacypolicies`
   Publish these exact routes or provide replacement public HTTPS URLs before submission.
2. **Account deletion:** authenticated in-app deletion is implemented. It removes Auth, profile,
   and device-token data and anonymizes retained trip history. Publish the public deletion-request
   page and document the retention period and legal purpose before submission.
3. **Physical-device release test:** install the minified signed APK and test Phone Auth,
   notifications, agreements, legal links, receipt upload, Razorpay, and TalkBack.
4. **Play Console details:** confirm developer display name/contact/address, app category, release
   countries, target audience, ads declaration, content-rating answers, and support contact.
5. **Reviewer/tester access:** configure permanent Firebase test phone accounts and provide closed
   testers if Google Play applies its testing requirement to this developer account.
6. **Store assets:** provide phone screenshots and a 1024x500 feature graphic. The committed icon
   source can be exported as the 512x512 Play icon.

## Play Console sequence

1. Create or select `com.travacs.travacs` and enroll in Play App Signing.
2. Complete App Access, Data Safety, privacy policy, account deletion, content rating, target
   audience, ads, support, and legal declarations.
3. Upload the signed AAB to internal testing.
4. Copy Play's app-signing SHA-1 and SHA-256 into the Firebase Android app. The upload-key
   fingerprints already registered are not a substitute for Play's app-signing fingerprints.
5. Configure Play Integrity for Firebase Phone Authentication and test a Play-installed build.
6. Resolve the pre-launch report, complete any required closed test, and use a staged production
   rollout.

## Release commands

```powershell
$env:JAVA_HOME = "C:\Users\sauprasad\dev-tools\jdk17\jdk-17.0.19+10"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Set-Location C:\Users\sauprasad\travacs\TravAcs\app

flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```
