# Google Play release checklist

## Engineering

- [x] Target API 36.
- [x] Dedicated upload signing key backed up outside Git.
- [x] Upload SHA-1 and SHA-256 registered with Firebase.
- [x] Release Internet and notification permissions.
- [x] Branded legacy and adaptive launcher icons.
- [x] R8 and resource shrinking.
- [x] Crashlytics release mapping integration.
- [x] Signed AAB generated and signature verified.
- [ ] Signed release APK tested on a physical Android device.
- [ ] Phone Auth, notifications, Razorpay, receipt upload, and legal links tested with R8 enabled.
- [ ] TalkBack end-to-end test completed.

## Public policy requirements

- [x] Terms URL published on the owned Firebase Hosting site.
- [x] Privacy URL published on the owned Firebase Hosting site.
- [x] Account-retention and deletion behavior approved: preserve anonymized trip history.
- [x] Authenticated in-app account deletion implemented.
- [x] Public account-deletion request URL published.
- [ ] Privacy policy and Play Data Safety answers match actual collection, sharing, and retention.

## Play Console

- [ ] Developer profile and support contact confirmed.
- [ ] App created for `com.travacs.travacs`.
- [ ] Play App Signing enabled.
- [ ] Play app-signing SHA-1 and SHA-256 registered with Firebase.
- [ ] App Access instructions and reviewer accounts configured.
- [ ] Store listing text, 512x512 icon, screenshots, and 1024x500 feature graphic uploaded.
- [ ] Category, countries, ads, target audience, content rating, and Data Safety completed.
- [ ] AAB uploaded to internal testing.
- [ ] Play-installed build passes Phone Auth and Play Integrity testing.
- [ ] Pre-launch report issues resolved.
- [ ] Required closed testing completed, if applicable.
- [ ] Staged production rollout submitted.
