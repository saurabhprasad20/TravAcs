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
  collectionGroup,
  query,
  where,
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

  it("the requester may cancel before anyone accepts", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(updateDoc(doc(alice, "requests/r1"), { status: "cancelled" }));
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
});

describe("ratings and devices", () => {
  it("a rater can create a 1-5 star rating but not out of range", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      setDoc(doc(alice, "ratings/r1_requester"), {
        raterId: "alice", rateeId: "vol", stars: 4,
      })
    );
    await assertFails(
      setDoc(doc(alice, "ratings/bad"), { raterId: "alice", rateeId: "vol", stars: 6 })
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
