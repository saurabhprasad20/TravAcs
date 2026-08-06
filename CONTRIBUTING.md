# Contributing to TravAcs

Thanks for helping build TravAcs. This project is accessibility-first and
safety-critical (it pairs visually-impaired travellers with in-person
assistants), so we keep a tight, review-gated workflow. Please read this before
opening your first pull request.

## Ground rules
- **`master` is protected.** Only the repository owner (**@saurabhprasad20**) can
  push to `master` directly. **Everyone else contributes via pull requests** from
  their own branch.
- **Every PR needs review before merge:**
  - **@saurabhprasad20's approval is required** (he is a [code owner](.github/CODEOWNERS)).
  - At least **one approving review from someone other than the PR author** is
    required.
  - **CI must be green** (`flutter analyze` + `flutter test`, and the backend
    emulator suites for backend changes).
- **Don't force-push or delete `master`** — it's blocked.
- **Never commit secrets or generated config** — `firebase_options.dart`,
  `google-services.json`, keystores, `key.properties`, Razorpay keys, and the
  root helper `*.js` scripts are gitignored. Regenerate them locally.

## Golden rules (do NOT regress)
These are enforced by tests and review. See [`AGENTS.md`](AGENTS.md) for the full
version:
1. **No raw errors to users** — route everything through the `Failure` taxonomy
   (`app/lib/core/error/`); raw detail only goes to Crashlytics.
2. **Accessibility is first-class** — semantic labels on every control, status is
   never colour-only, announce state changes, touch targets ≥48dp, text scale
   clamped to `[1.0, 1.8]`. `test/accessibility_test.dart` guards this.
3. **Privileged writes are server-only** — clients can't set role, verification,
   ratings, amounts, or assignments; state transitions go through Cloud Functions
   and are enforced by Firestore Security Rules.

## Workflow
1. **Request access.** Ask @saurabhprasad20 for **Write** collaborator access.
2. **Sync and branch:**
   ```powershell
   git checkout master
   git pull
   git checkout -b <your-handle>/<short-topic>   # e.g. asha/fix-otp-timeout
   ```
3. **Set up the app** (one-time — the config is gitignored, so the app won't
   build without it):
   ```powershell
   cd app
   flutterfire configure --project=travacs-dev
   flutter pub get
   ```
4. **Make a focused change.** Keep PRs small and single-purpose. Update docs/tests
   alongside code.
5. **Run the quality gates locally** (a PR won't merge if these fail):
   ```powershell
   cd app
   flutter analyze          # must be clean
   flutter test             # all tests green
   ```
   Backend changes also need the emulator suites (from `firebase/`, JDK 17 pins
   firebase-tools@13 — see [`AGENTS.md`](AGENTS.md)):
   ```powershell
   npx -y firebase-tools@13 emulators:exec --only firestore --project demo-travacs "npm --prefix rules-tests test"
   npx -y firebase-tools@13 emulators:exec --only firestore --project demo-travacs "npm --prefix functions test"
   ```
6. **Push your branch** (not `master`):
   ```powershell
   git push -u origin <your-handle>/<short-topic>
   ```
7. **Open a pull request** into `master`:
   - Target branch: `master`.
   - **Request @saurabhprasad20 as a reviewer**, plus one other reviewer.
   - Describe *what* changed, *why*, and *how you tested it* (device, tests run).
   - Link any related issue.
8. **Iterate on feedback.** Push follow-up commits to the same branch. Note that
   new commits **dismiss existing approvals**, so re-request review after
   changes. Once approved and green, the owner merges.

## Commit messages
- Use a short imperative subject line (e.g. `fix: dismiss reschedule sheet on
  cancel`), an optional body explaining *why*, and keep unrelated changes out.

## Reporting bugs / proposing features
Open a GitHub Issue with clear reproduction steps (device, OS, role, and what you
expected vs. saw). For accessibility bugs, describe the screen-reader (TalkBack)
behaviour you observed.

## Where to look
| Topic | File |
|---|---|
| Agent & developer guide (start here) | [`AGENTS.md`](AGENTS.md) |
| Behavior baseline (regression reference) | [`docx/behavior_baseline.md`](docx/behavior_baseline.md) |
| Deep system design | [`docx/design_travacs.md`](docx/design_travacs.md) |
| Branch-protection rules (owner setup) | [`docx/branch-protection-setup.md`](docx/branch-protection-setup.md) |
| Security rules | [`firebase/firestore.rules`](firebase/firestore.rules) |
| Cloud Functions | [`firebase/functions/src/index.ts`](firebase/functions/src/index.ts) |
