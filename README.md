# TravAcs

**TravAcs** is an accessibility-first mobile app that pairs visually-impaired
**Users** with verified **TravAcsers** (assistants) for short, paid, in-person
travel and mobility assistance across India.

Our goal is simple: make independent travel easier and safer for people with
visual impairment by connecting them, on demand, with trusted, verified helpers.

> **Status:** in active development, currently in a limited test phase
> (only ₹1 is collected at checkout while we test payments).

## What it does
- **Sign in with your phone** (OTP) and set up a simple profile as a **User** or
  a **TravAcser**.
- **Users** request assistance for a trip — city, date/time, meeting point,
  destination, number of travellers and helpers needed, and any gender
  preference.
- Requests are **broadcast** to verified TravAcsers in the same city; the first
  to accept is matched (first-come, first-served).
- On the day, the trip **starts** (the TravAcser confirms a code the User
  shares), the two travel together, then the trip is **completed** and
  **paid in-app**, and both sides leave a **rating**.
- Users can **reschedule** or **cancel**; either side can cancel before the trip
  starts. An **admin** verifies TravAcsers before they can accept work.

Pricing (post test-phase): **₹149/hr** per TravAcser assisting 1 traveller,
**₹210/hr** assisting 2, plus **₹100 travel** per TravAcser, with a 1-hour
minimum.

## Built with
Flutter (Dart) on the front end and **Firebase** on the back end (Phone Auth,
Cloud Firestore, Cloud Functions, notifications, crash reporting), with
**Razorpay** for in-app payments. The app is designed to be **accessibility-first**
throughout (full screen-reader support, no colour-only status, large touch
targets).

## Repository layout
```
app/        Flutter application
firebase/   Firestore rules + indexes + Cloud Functions
docx/        Design, requirements and engineering docs
AGENTS.md   Full developer & contributor guide (setup, commands, architecture)
```

## Getting started (developers)
The complete development guide — environment setup, build/run/test commands,
architecture, and backend deploy steps — lives in **[`AGENTS.md`](AGENTS.md)**.
In short:

```powershell
cd app
flutterfire configure --project=travacs-dev   # one-time; writes gitignored config
flutter pub get
flutter run                                    # to a connected device
```

Before pushing changes, run the quality gates:

```powershell
cd app
flutter analyze      # must be clean
flutter test         # all tests green
```

## Contributing
We welcome contributions! The `master` branch is **protected** — all changes
land through a **pull request** that is reviewed and approved before it is
merged. Direct pushes to `master` are not allowed.

1. **Fork or request collaborator access**, then clone the repository.
2. **Create a branch off `master`** and push your branch (not `master`):
   ```powershell
   git checkout master; git pull
   git checkout -b <your-handle>/<short-topic>
   git push -u origin <your-handle>/<short-topic>
   ```
3. **Make a focused change** and run the quality gates (`flutter analyze` +
   `flutter test`; backend changes also need the emulator suites in `AGENTS.md`).
   Please keep the project's principles intact — **accessibility-first**, and
   **users never see raw errors**.
4. **Open a pull request into `master`** and request a review:
   - At least **one approving review** (from someone other than the author) is
     required, and **CI must be green**.
   - In the description, say what changed, why, and how you tested it.
5. **Address review feedback** on the same branch (pushing new commits dismisses
   prior approvals, so re-request review), and a maintainer merges once approved.

Found a bug or have an idea? **Open an issue** with clear steps to reproduce
(device, role, what you expected vs. saw).

### Continuous deployment
Every merge to `master` runs the test suite and then **automatically deploys the
backend** (Cloud Functions, Firestore rules & indexes) — no manual
`firebase deploy`. Contributors never get deploy access; only merged code on
`master` ships.

## Documentation
| Topic | Where |
|---|---|
| Full developer & contributor guide | [`AGENTS.md`](AGENTS.md) |
| Product requirements | [`docx/appRequirements.md`](docx/appRequirements.md) |
| System design | [`docx/design_travacs.md`](docx/design_travacs.md) |
| Engineering principles | [`docx/EngPrinciples.md`](docx/EngPrinciples.md) |

## A note on privacy & secrets
TravAcs handles personal data responsibly. Project config and credentials
(`firebase_options.dart`, `google-services.json`, keystores, payment keys) are
**never committed** — they're generated or stored securely outside the repo.
