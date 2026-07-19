"use strict";

// Firestore Security Rules tests (M10b). Run against the Firestore emulator:
//   firebase emulators:exec --only firestore --project demo-travacs \
//     "npm --prefix rules-tests test"
//
// Verifies the access matrix and field-level protection in firestore.rules:
// default-deny, self-scoped reads, region-scoped request reads, protected
// fields not client-writable, and function-only subcollections.

const { readFileSync } = require("fs");
const path = require("path");
const assert = require("assert");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  collectionGroup,
  query,
  where,
  or,
  and,
  setLogLevel,
} = require("firebase/firestore");

const PROJECT_ID = "demo-travacs";
const CITY = "delhi_ncr";

let testEnv;

// A minimal valid profile document.
function profile(role, extra = {}) {
  return {
    role,
    fullName: "Test",
    isActive: true,
    ratingAvg: 0,
    ratingCount: 0,
    serviceArea: "delhi_ncr",
    serviceCity: CITY,
    ...(role === "volunteer" ? { verificationStatus: "pending" } : {}),
    ...extra,
  };
}

function request(requesterId, extra = {}) {
  return {
    requesterId,
    requesterName: "U",
    volunteerId: null,
    status: "broadcast",
    serviceArea: "delhi_ncr",
    serviceCity: CITY,
    acceptedCount: 0,
    numTravellers: 1,
    numTravAcsers: 1,
    scheduledDate: new Date(),
    scheduledStartAt: new Date(Date.now() + 3600_000),
    startTime: "10:00",
    expectedDurationMinutes: 60,
    meetingPoint: "A",
    destination: "B",
    estimatedAmountInr: 135,
    ...extra,
  };
}

// Seed docs with rules bypassed.
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

before(async () => {
  setLogLevel("error"); // silence the modular SDK's noisy warnings
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe("profiles", () => {
  it("a user can read their own profile but not another's", async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "profiles/alice"), profile("requester"));
      await setDoc(doc(db, "profiles/bob"), profile("requester"));
    });
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(getDoc(doc(alice, "profiles/alice")));
    await assertFails(getDoc(doc(alice, "profiles/bob")));
  });

  it("an admin can read any profile", async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "profiles/bob"), profile("requester"));
    });
    const admin = testEnv.authenticatedContext("root", { admin: true }).firestore();
    await assertSucceeds(getDoc(doc(admin, "profiles/bob")));
  });

  it("unauthenticated reads are denied", async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "profiles/alice"), profile("requester"));
    });
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, "profiles/alice")));
  });

  it("can create own profile with zeroed ratings", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(setDoc(doc(alice, "profiles/alice"), profile("requester")));
  });

  it("cannot create a profile with non-zero ratings", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(alice, "profiles/alice"), profile("requester", { ratingAvg: 5 }))
    );
  });

  it("a volunteer cannot self-approve at creation", async () => {
    const v = testEnv.authenticatedContext("v").firestore();
    await assertFails(
      setDoc(doc(v, "profiles/v"), profile("volunteer", { verificationStatus: "approved" }))
    );
  });

  it("can edit own editable fields but not role/verification/ratings", async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "profiles/v"), profile("volunteer"));
    });
    const v = testEnv.authenticatedContext("v").firestore();
    await assertSucceeds(updateDoc(doc(v, "profiles/v"), { fullName: "New Name" }));
    await assertFails(updateDoc(doc(v, "profiles/v"), { role: "admin" }));
    await assertFails(updateDoc(doc(v, "profiles/v"), { verificationStatus: "approved" }));
    await assertFails(updateDoc(doc(v, "profiles/v"), { ratingAvg: 5 }));
  });

  it("a TravAcser cannot change their gender after creation (H4)", async () => {
    // Gender is trusted for strict same-gender matching, so it must be
    // immutable — otherwise a TravAcser could flip it to reach a request meant
    // for the other gender.
    await seed(async (db) => {
      await setDoc(doc(db, "profiles/v"), profile("volunteer", { gender: "male" }));
    });
    const v = testEnv.authenticatedContext("v").firestore();
    await assertFails(updateDoc(doc(v, "profiles/v"), { gender: "female" }));
    // an unrelated editable field still works (gender unchanged)
    await assertSucceeds(updateDoc(doc(v, "profiles/v"), { fullName: "Renamed" }));
  });

  it("profiles cannot be deleted", async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "profiles/alice"), profile("requester"));
    });
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(deleteDoc(doc(alice, "profiles/alice")));
  });
});

describe("requests", () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "requests/r1"), request("alice"));
      // an approved, active TravAcser in the same city
      await setDoc(doc(db, "profiles/vol"),
        profile("volunteer", { verificationStatus: "approved" }));
      // an approved TravAcser in a DIFFERENT city
      await setDoc(doc(db, "profiles/farvol"),
        profile("volunteer", { verificationStatus: "approved", serviceCity: "mumbai" }));
      // a pending (not approved) TravAcser in the same city
      await setDoc(doc(db, "profiles/pending"), profile("volunteer"));
    });
  });

  it("the requester can read their own request", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(getDoc(doc(alice, "requests/r1")));
  });

  it("an approved TravAcser in the same city can read a broadcast request", async () => {
    const vol = testEnv.authenticatedContext("vol").firestore();
    await assertSucceeds(getDoc(doc(vol, "requests/r1")));
  });

  it("a TravAcser in another city cannot read it", async () => {
    const far = testEnv.authenticatedContext("farvol").firestore();
    await assertFails(getDoc(doc(far, "requests/r1")));
  });

  it("a non-approved TravAcser cannot read it", async () => {
    const pending = testEnv.authenticatedContext("pending").firestore();
    await assertFails(getDoc(doc(pending, "requests/r1")));
  });

  it("an opposite-gender TravAcser cannot read a strict same-gender request; same gender can", async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "requests/rg"), request("alice", {
        genderPreference: "strict_same_gender", requesterGender: "female",
        genderRestricted: true, genderWidened: false,
      }));
      await setDoc(doc(db, "profiles/male1"),
        profile("volunteer", { verificationStatus: "approved", gender: "male" }));
      await setDoc(doc(db, "profiles/female1"),
        profile("volunteer", { verificationStatus: "approved", gender: "female" }));
    });
    const male = testEnv.authenticatedContext("male1").firestore();
    const female = testEnv.authenticatedContext("female1").firestore();
    await assertFails(getDoc(doc(male, "requests/rg")));
    await assertSucceeds(getDoc(doc(female, "requests/rg")));
  });

  it("an opposite-gender TravAcser can read a widened strict request", async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "requests/rg2"), request("alice", {
        genderPreference: "strict_same_gender", requesterGender: "female",
        genderRestricted: true, genderWidened: true,
      }));
      await setDoc(doc(db, "profiles/male2"),
        profile("volunteer", { verificationStatus: "approved", gender: "male" }));
    });
    const male = testEnv.authenticatedContext("male2").firestore();
    await assertSucceeds(getDoc(doc(male, "requests/rg2")));
  });

  it("can create your own request, not one attributed to someone else", async () => {
    const carol = testEnv.authenticatedContext("carol").firestore();
    await assertSucceeds(setDoc(doc(carol, "requests/r2"), request("carol")));
    await assertFails(setDoc(doc(carol, "requests/r3"), request("alice")));
  });

  it("cannot create a request that is pre-assigned to a TravAcser", async () => {
    const carol = testEnv.authenticatedContext("carol").firestore();
    await assertFails(
      setDoc(doc(carol, "requests/r4"), request("carol", { volunteerId: "vol" }))
    );
  });

  it("cannot create a request with a forged (non-zero) acceptedCount", async () => {
    const carol = testEnv.authenticatedContext("carol").firestore();
    await assertFails(
      setDoc(doc(carol, "requests/r5"), request("carol", { acceptedCount: 5 }))
    );
    await assertFails(
      setDoc(doc(carol, "requests/r6"), request("carol", { acceptedCount: -100 }))
    );
  });

  it("cannot create a request with an out-of-range TravAcser count", async () => {
    const carol = testEnv.authenticatedContext("carol").firestore();
    await assertFails(
      setDoc(doc(carol, "requests/r7"), request("carol", { numTravAcsers: 50 }))
    );
    await assertFails(
      setDoc(doc(carol, "requests/r8"), request("carol", { numTravAcsers: 0 }))
    );
  });

  it("cannot create a request carrying server-managed payment fields (allowlist)", async () => {
    const carol = testEnv.authenticatedContext("carol").firestore();
    await assertFails(
      setDoc(doc(carol, "requests/rf1"), request("carol", { tripAmountInr: 999 }))
    );
    await assertFails(
      setDoc(doc(carol, "requests/rf2"), request("carol", { requesterPaidAt: new Date() }))
    );
    await assertFails(
      setDoc(doc(carol, "requests/rf3"), request("carol", { razorpayOrderId: "order_x" }))
    );
  });

  it("cannot create a request without a scheduledStartAt timestamp (H6)", async () => {
    const carol = testEnv.authenticatedContext("carol").firestore();
    const noAnchor = request("carol");
    delete noAnchor.scheduledStartAt;
    await assertFails(setDoc(doc(carol, "requests/rna"), noAnchor));
    // a non-timestamp anchor is also rejected
    await assertFails(
      setDoc(doc(carol, "requests/rnb"), request("carol", { scheduledStartAt: "soon" }))
    );
  });

  describe("available-requests listing is authorizable (H3)", () => {
    beforeEach(async () => {
      await seed(async (db) => {
        await setDoc(doc(db, "requests/open1"),
          request("alice", { genderRestricted: false }));
        await setDoc(doc(db, "requests/strictF"), request("alice", {
          genderPreference: "strict_same_gender", requesterGender: "female",
          genderRestricted: true, genderWidened: false,
        }));
        await setDoc(doc(db, "profiles/maleVol"),
          profile("volunteer", { verificationStatus: "approved", gender: "male" }));
        await setDoc(doc(db, "profiles/femVol"),
          profile("volunteer", { verificationStatus: "approved", gender: "female" }));
      });
    });

    it("the gender-constrained listing (client's real query) succeeds for a male TravAcser", async () => {
      const male = testEnv.authenticatedContext("maleVol").firestore();
      const q = query(collection(male, "requests"),
        and(
          where("status", "==", "broadcast"),
          where("serviceCity", "==", CITY),
          or(
            where("genderRestricted", "==", false),
            where("genderWidened", "==", true),
            where("requesterGender", "==", "male"),
          )));
      const snap = await assertSucceeds(getDocs(q));
      const ids = snap.docs.map((d) => d.id).sort();
      assert.deepEqual(ids, ["open1"]); // strictF (female-only) excluded
    });

    it("a female TravAcser's constrained listing includes the strict female request", async () => {
      const fem = testEnv.authenticatedContext("femVol").firestore();
      const q = query(collection(fem, "requests"),
        and(
          where("status", "==", "broadcast"),
          where("serviceCity", "==", CITY),
          or(
            where("genderRestricted", "==", false),
            where("genderWidened", "==", true),
            where("requesterGender", "==", "female"),
          )));
      const snap = await assertSucceeds(getDocs(q));
      const ids = snap.docs.map((d) => d.id).sort();
      assert.deepEqual(ids, ["open1", "strictF"]);
    });
  });

  it("the requester may cancel before anyone accepts", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(updateDoc(doc(alice, "requests/r1"), { status: "cancelled" }));
  });

  it("a cancel update may only change status (not ownership/amounts)", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    // Sneaking a requesterId change (to forge a trip into someone else's history)
    // or a payment field alongside the cancel must be rejected.
    await assertFails(
      updateDoc(doc(alice, "requests/r1"), { status: "cancelled", requesterId: "mallory" })
    );
    await assertFails(
      updateDoc(doc(alice, "requests/r1"), { status: "cancelled", tripAmountInr: 5 })
    );
  });

  it("cannot cancel once a slot is filled", async () => {
    await seed(async (db) => {
      await updateDoc(doc(db, "requests/r1"), { acceptedCount: 1 });
    });
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(updateDoc(doc(alice, "requests/r1"), { status: "cancelled" }));
  });

  it("clients cannot self-assign (only Cloud Functions can)", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(updateDoc(doc(alice, "requests/r1"), { status: "assigned" }));
  });
});

describe("assignments and secrets (function-only writes)", () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "requests/r1"), request("alice"));
      await setDoc(doc(db, "requests/r1/assignments/vol"), {
        volunteerId: "vol",
        requesterId: "alice",
        tripStatus: "assigned",
      });
    });
  });

  it("the assigned TravAcser and the requester can read the assignment", async () => {
    const vol = testEnv.authenticatedContext("vol").firestore();
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(getDoc(doc(vol, "requests/r1/assignments/vol")));
    await assertSucceeds(getDoc(doc(alice, "requests/r1/assignments/vol")));
  });

  it("an unrelated TravAcser cannot read someone else's assignment", async () => {
    const other = testEnv.authenticatedContext("other").firestore();
    await assertFails(getDoc(doc(other, "requests/r1/assignments/vol")));
  });

  it("clients cannot write assignments", async () => {
    const vol = testEnv.authenticatedContext("vol").firestore();
    await assertFails(
      setDoc(doc(vol, "requests/r1/assignments/vol"), { tripStatus: "started" })
    );
  });

  it("a TravAcser can list their OWN assignments via collectionGroup", async () => {
    const vol = testEnv.authenticatedContext("vol").firestore();
    await assertSucceeds(getDocs(query(
      collectionGroup(vol, "assignments"),
      where("volunteerId", "==", "vol"),
    )));
  });

  it("a TravAcser cannot collectionGroup-read someone else's assignments", async () => {
    const other = testEnv.authenticatedContext("other").firestore();
    // Query scoped to vol's docs but the caller is 'other' → denied by rules.
    await assertFails(getDocs(query(
      collectionGroup(other, "assignments"),
      where("volunteerId", "==", "vol"),
    )));
  });

  it("a requester can list assignments across THEIR OWN requests via collectionGroup", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(getDocs(query(
      collectionGroup(alice, "assignments"),
      where("requesterId", "==", "alice"),
    )));
  });

  it("a stranger cannot collectionGroup-read a requester's assignments", async () => {
    const other = testEnv.authenticatedContext("other").firestore();
    await assertFails(getDocs(query(
      collectionGroup(other, "assignments"),
      where("requesterId", "==", "alice"),
    )));
  });
});

describe("ratings and devices", () => {
  it("clients cannot create ratings directly (server-only via submitRating)", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(alice, "ratings/r1_requester"), {
        raterId: "alice", rateeId: "vol", stars: 4,
      })
    );
  });

  it("cannot submit a rating as someone else", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(alice, "ratings/x"), { raterId: "mallory", rateeId: "vol", stars: 3 })
    );
  });

  it("device tokens are private to their owner", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    const mallory = testEnv.authenticatedContext("mallory").firestore();
    await assertSucceeds(setDoc(doc(alice, "devices/alice/tokens/t1"), { ts: 1 }));
    await assertFails(setDoc(doc(mallory, "devices/alice/tokens/t2"), { ts: 1 }));
  });
});

// Sanity that the harness itself is wired up.
it("the rules file is non-empty", () => {
  const rules = readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8");
  assert.ok(rules.includes("isApprovedVolunteer"));
});
