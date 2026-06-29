// Cloud Functions tests (M10b). The callables are invoked in-process via
// firebase-functions-test, with all Firestore reads/writes hitting the
// Firestore emulator. Run with:
//   firebase emulators:exec --only firestore --project demo-travacs \
//     "npm --prefix functions test"
// (emulators:exec sets FIRESTORE_EMULATOR_HOST + GCLOUD_PROJECT for us.)

import * as assert from "assert";
import functionsTest from "firebase-functions-test";

const fft = functionsTest({projectId: "demo-travacs"});

import {getFirestore, Timestamp} from "firebase-admin/firestore";
import * as fns from "../src/index";

const db = getFirestore();

const acceptRequest = fft.wrap(fns.acceptRequest);
const completeTrip = fft.wrap(fns.completeTrip);
const rescheduleTrip = fft.wrap(fns.rescheduleTrip);
const cancelTrip = fft.wrap(fns.cancelTrip);
const markPaid = fft.wrap(fns.markPaid);
const markReceived = fft.wrap(fns.markReceived);
const submitRating = fft.wrap(fns.submitRating);
const setVerification = fft.wrap(fns.setVerification);

const HOUR = 60 * 60000;

// Build a CallableRequest-shaped payload for the wrapped v2 function.
function call(data: any, uid?: string, token: Record<string, any> = {}): any {
  return {data, auth: uid ? {uid, token: {...token}} : undefined};
}

async function clearDb(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(
    `http://${host}/emulator/v1/projects/demo-travacs/databases/(default)/documents`,
    {method: "DELETE"}
  );
}

async function approvedVolunteer(id: string, city = "delhi_ncr"): Promise<void> {
  await db.doc(`profiles/${id}`).set({
    role: "volunteer",
    verificationStatus: "approved",
    isActive: true,
    fullName: id,
    phone: "+910000000000",
    serviceCity: city,
  });
}

async function broadcastRequest(id: string, extra: any = {}): Promise<void> {
  await db.doc(`profiles/alice`).set({role: "requester", fullName: "Alice", phone: "+91999"});
  await db.doc(`requests/${id}`).set({
    requesterId: "alice",
    requesterName: "Alice",
    status: "broadcast",
    serviceCity: "delhi_ncr",
    acceptedCount: 0,
    numTravAcsers: 1,
    numTravellers: 1,
    genderPreference: "prefer_same_gender",
    expectedDurationMinutes: 120,
    startTime: "10:00",
    scheduledStartAt: Timestamp.fromMillis(Date.now() + 24 * HOUR),
    ...extra,
  });
}

after(() => fft.cleanup());
beforeEach(clearDb);

describe("acceptRequest (slot-filling FCFS)", () => {
  it("fills the only slot and denormalizes the trip onto the assignment", async () => {
    await approvedVolunteer("vol");
    await broadcastRequest("r1");

    const res: any = await acceptRequest(call({requestId: "r1"}, "vol"));
    assert.equal(res.code, "ACCEPTED");
    assert.equal(res.slotsRemaining, 0);

    const r = (await db.doc("requests/r1").get()).data()!;
    assert.equal(r.acceptedCount, 1);
    assert.equal(r.status, "assigned"); // auto-transition when full

    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.tripStatus, "assigned");
    assert.equal(a.amountInrEstimate, 270); // 2h * 135
    assert.equal(a.genderPreference, "prefer_same_gender");
    assert.ok(a.scheduledStartAt, "scheduledStartAt denormalized");

    // No OTP secret is created any more (auto-start, M12).
    assert.ok(!(await db.doc("requests/r1/secrets/vol").get()).exists);
  });

  it("rejects a second TravAcser once the request is full", async () => {
    await approvedVolunteer("vol");
    await approvedVolunteer("vol2");
    await broadcastRequest("r1");
    await acceptRequest(call({requestId: "r1"}, "vol"));

    await assert.rejects(
      () => acceptRequest(call({requestId: "r1"}, "vol2")),
      /no longer open|filled/i
    );
  });

  it("rejects a TravAcser who is not approved", async () => {
    await db.doc("profiles/pending").set({
      role: "volunteer", verificationStatus: "pending", isActive: true,
      serviceCity: "delhi_ncr",
    });
    await broadcastRequest("r1");
    await assert.rejects(
      () => acceptRequest(call({requestId: "r1"}, "pending")),
      /approved/i
    );
  });
});

describe("completeTrip (ends an auto-started trip + bills)", () => {
  it("bills from scheduledStartAt and completes the request", async () => {
    await db.doc("requests/r1").set({requesterId: "alice", status: "assigned"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "assigned",
      scheduledStartAt: Timestamp.fromMillis(Date.now() - 2 * HOUR), // started 2h ago
    });

    const res: any = await completeTrip(call({requestId: "r1", volunteerId: "vol"}, "vol"));
    assert.equal(res.code, "COMPLETED");
    assert.ok(Math.abs(res.amountInr - 270) <= 3, `~270 expected, got ${res.amountInr}`);

    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.tripStatus, "completed");
    assert.equal(a.paymentStatus, "pending");

    const r = (await db.doc("requests/r1").get()).data()!;
    assert.equal(r.status, "completed");
  });

  it("cannot end a trip that has not started yet", async () => {
    await db.doc("requests/r1").set({requesterId: "alice", status: "assigned"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "assigned",
      scheduledStartAt: Timestamp.fromMillis(Date.now() + 2 * HOUR),
    });
    await assert.rejects(
      () => completeTrip(call({requestId: "r1", volunteerId: "vol"}, "vol")),
      /not started/i
    );
  });
});

describe("rescheduleTrip", () => {
  it("the requester moves the trip time; a stranger cannot", async () => {
    await approvedVolunteer("vol");
    await broadcastRequest("r1"); // scheduledStartAt is in the future
    await acceptRequest(call({requestId: "r1"}, "vol"));

    const newMs = Date.now() + 48 * HOUR;
    await assert.rejects(
      () => rescheduleTrip(call({
        requestId: "r1", scheduledDateMs: newMs, startTime: "14:00",
        scheduledStartAtMs: newMs,
      }, "mallory")),
      /only the user/i
    );

    await rescheduleTrip(call({
      requestId: "r1", scheduledDateMs: newMs, startTime: "14:00",
      scheduledStartAtMs: newMs,
    }, "alice"));

    const r = (await db.doc("requests/r1").get()).data()!;
    assert.equal(r.startTime, "14:00");
    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.startTime, "14:00"); // denormalized to the assignment
  });
});

describe("cancelTrip", () => {
  it("the requester cancels the whole request + its assignments", async () => {
    await approvedVolunteer("vol");
    await broadcastRequest("r1");
    await acceptRequest(call({requestId: "r1"}, "vol"));

    await cancelTrip(call({requestId: "r1"}, "alice"));
    const r = (await db.doc("requests/r1").get()).data()!;
    assert.equal(r.status, "cancelled");
    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.tripStatus, "cancelled");
  });

  it("a TravAcser releases just their slot and reopens the request", async () => {
    await approvedVolunteer("vol");
    await broadcastRequest("r1");
    await acceptRequest(call({requestId: "r1"}, "vol")); // fills -> assigned

    await cancelTrip(call({requestId: "r1"}, "vol"));
    const r = (await db.doc("requests/r1").get()).data()!;
    assert.equal(r.status, "broadcast"); // reopened for others
    assert.equal(r.acceptedCount, 0);
    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.tripStatus, "cancelled");
  });
});

describe("two-sided payment", () => {
  async function seedCompleted(): Promise<void> {
    await db.doc("requests/r1").set({requesterId: "alice"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice",
      tripStatus: "completed", paymentStatus: "pending",
    });
  }

  it("paid then received reaches confirmed", async () => {
    await seedCompleted();
    await markPaid(call({requestId: "r1", volunteerId: "vol"}, "alice"));
    let a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.paymentStatus, "awaiting_other");

    await markReceived(call({requestId: "r1"}, "vol"));
    a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.paymentStatus, "confirmed");
  });

  it("only the requester can mark Paid", async () => {
    await seedCompleted();
    await assert.rejects(
      () => markPaid(call({requestId: "r1", volunteerId: "vol"}, "mallory")),
      /User/i
    );
  });
});

describe("submitRating", () => {
  it("updates the ratee's rolling average and blocks duplicates", async () => {
    await db.doc("profiles/vol").set({role: "volunteer", ratingAvg: 0, ratingCount: 0});
    await db.doc("requests/r1").set({requesterId: "alice"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "completed",
    });

    await submitRating(call({requestId: "r1", volunteerId: "vol", stars: 4}, "alice"));
    const p = (await db.doc("profiles/vol").get()).data()!;
    assert.equal(p.ratingCount, 1);
    assert.equal(p.ratingAvg, 4);

    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.requesterRatingStars, 4);

    await assert.rejects(
      () => submitRating(call({requestId: "r1", volunteerId: "vol", stars: 5}, "alice")),
      /already rated/i
    );
  });
});

describe("setVerification (admin gate)", () => {
  it("an admin approves a TravAcser; a non-admin is denied", async () => {
    await db.doc("profiles/vol").set({role: "volunteer", verificationStatus: "pending"});

    await assert.rejects(
      () => setVerification(call({uid: "vol", decision: "approved"}, "mallory")),
      /admin/i
    );

    await setVerification(call({uid: "vol", decision: "approved"}, "root", {admin: true}));
    const p = (await db.doc("profiles/vol").get()).data()!;
    assert.equal(p.verificationStatus, "approved");
  });
});
