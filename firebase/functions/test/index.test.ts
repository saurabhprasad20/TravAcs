// Cloud Functions tests (M10b). The callables are invoked in-process via
// firebase-functions-test, with all Firestore reads/writes hitting the
// Firestore emulator. Run with:
//   firebase emulators:exec --only firestore --project demo-travacs \
//     "npm --prefix functions test"
// (emulators:exec sets FIRESTORE_EMULATOR_HOST + GCLOUD_PROJECT for us.)

import * as assert from "assert";
import * as crypto from "crypto";
import functionsTest from "firebase-functions-test";

const fft = functionsTest({projectId: "demo-travacs"});

import {getFirestore, Timestamp} from "firebase-admin/firestore";
import * as fns from "../src/index";

const db = getFirestore();

const acceptRequest = fft.wrap(fns.acceptRequest);
const completeTrip = fft.wrap(fns.completeTrip);
const startTrip = fft.wrap(fns.startTrip);
const rescheduleTrip = fft.wrap(fns.rescheduleTrip);
const cancelTrip = fft.wrap(fns.cancelTrip);
const respondReschedule = fft.wrap(fns.respondReschedule);
const markPaid = fft.wrap(fns.markPaid);
const markReceived = fft.wrap(fns.markReceived);
const submitRating = fft.wrap(fns.submitRating);
const setVerification = fft.wrap(fns.setVerification);
const verifyRazorpayPayment = fft.wrap(fns.verifyRazorpayPayment);
const logManualTrip = fft.wrap(fns.logManualTrip);
const widenGenderRequests = fft.wrap(fns.widenGenderRequests);

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

async function approvedVolunteer(id: string, city = "delhi_ncr", gender?: string): Promise<void> {
  await db.doc(`profiles/${id}`).set({
    role: "volunteer",
    verificationStatus: "approved",
    isActive: true,
    fullName: id,
    phone: "+910000000000",
    serviceCity: city,
    ...(gender ? {gender} : {}),
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
    assert.equal(a.amountInrEstimate, 280); // 2h = 4 half-hour blocks * ₹70
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

  it("rejects a second trip on the SAME day but allows a different day", async () => {
    await approvedVolunteer("vol");
    const day1 = Date.now() + 24 * HOUR;
    await broadcastRequest("r1", {scheduledStartAt: Timestamp.fromMillis(day1)});
    await broadcastRequest("r2", {scheduledStartAt: Timestamp.fromMillis(day1 + 3 * HOUR)});
    await broadcastRequest("r3", {scheduledStartAt: Timestamp.fromMillis(day1 + 48 * HOUR)});

    await acceptRequest(call({requestId: "r1"}, "vol"));
    // Same calendar day -> blocked.
    await assert.rejects(
      () => acceptRequest(call({requestId: "r2"}, "vol")),
      /more than one trip on a day/i
    );
    // Two days later -> allowed.
    const res: any = await acceptRequest(call({requestId: "r3"}, "vol"));
    assert.equal(res.code, "ACCEPTED");
  });

  it("lets a TravAcser re-accept a request they previously cancelled", async () => {
    await approvedVolunteer("vol");
    await broadcastRequest("r1");

    await acceptRequest(call({requestId: "r1"}, "vol"));
    // TravAcser cancels their slot -> request reopens, cancelled assignment
    // doc remains behind.
    await cancelTrip(call({requestId: "r1"}, "vol"));
    const reopened = (await db.doc("requests/r1").get()).data()!;
    assert.equal(reopened.status, "broadcast");
    assert.equal(reopened.acceptedCount, 0);

    // Re-accepting must succeed (not "already accepted").
    const res: any = await acceptRequest(call({requestId: "r1"}, "vol"));
    assert.equal(res.code, "ACCEPTED");
    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.tripStatus, "assigned"); // overwritten cleanly
  });
});

describe("gender matching (acceptRequest + widenGenderRequests)", () => {
  // A strict same-gender request from a female requester.
  async function strictFemaleRequest(id: string, extra: any = {}): Promise<void> {
    await broadcastRequest(id, {
      genderPreference: "strict_same_gender",
      requesterGender: "female",
      genderRestricted: true,
      genderWidened: false,
      ...extra,
    });
  }

  it("rejects an opposite-gender TravAcser on a strict request", async () => {
    await approvedVolunteer("vol", "delhi_ncr", "male");
    await strictFemaleRequest("r1");
    await assert.rejects(
      () => acceptRequest(call({requestId: "r1"}, "vol")),
      /limited to a specific gender/i
    );
  });

  it("allows a same-gender TravAcser on a strict request", async () => {
    await approvedVolunteer("vol", "delhi_ncr", "female");
    await strictFemaleRequest("r1");
    const res: any = await acceptRequest(call({requestId: "r1"}, "vol"));
    assert.equal(res.code, "ACCEPTED");
  });

  it("allows any gender once the request has widened", async () => {
    await approvedVolunteer("vol", "delhi_ncr", "male");
    await strictFemaleRequest("r1", {genderWidened: true});
    const res: any = await acceptRequest(call({requestId: "r1"}, "vol"));
    assert.equal(res.code, "ACCEPTED");
  });

  it("does not restrict a preferred/any request", async () => {
    await approvedVolunteer("vol", "delhi_ncr", "male");
    await broadcastRequest("r1", {
      genderPreference: "prefer_same_gender",
      requesterGender: "female",
      genderRestricted: false,
    });
    const res: any = await acceptRequest(call({requestId: "r1"}, "vol"));
    assert.equal(res.code, "ACCEPTED");
  });

  it("widenGenderRequests flips genderWidened once past genderWidenAt", async () => {
    await strictFemaleRequest("due", {
      genderWidenAt: Timestamp.fromMillis(Date.now() - 60000), // due
    });
    await strictFemaleRequest("notdue", {
      genderWidenAt: Timestamp.fromMillis(Date.now() + HOUR), // not yet
    });
    await widenGenderRequests({} as any);
    assert.equal((await db.doc("requests/due").get()).data()!.genderWidened, true);
    assert.equal((await db.doc("requests/notdue").get()).data()!.genderWidened, false);
  });
});

describe("startTrip (code-gated status flip, TravAcser-driven)", () => {
  it("the TravAcser starts an assigned trip after its scheduled time", async () => {
    await db.doc("requests/r1").set({requesterId: "alice", status: "assigned"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "assigned",
      scheduledStartAt: Timestamp.fromMillis(Date.now() - HOUR),
    });
    const res: any = await startTrip(call({requestId: "r1", volunteerId: "vol"}, "vol"));
    assert.equal(res.code, "STARTED");
    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.tripStatus, "started");
    assert.ok(a.startedAt);
  });

  it("can start early — before the scheduled time (parties met sooner)", async () => {
    await db.doc("requests/r1").set({requesterId: "alice", status: "assigned"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "assigned",
      scheduledStartAt: Timestamp.fromMillis(Date.now() + HOUR), // still in the future
    });
    const res: any = await startTrip(call({requestId: "r1", volunteerId: "vol"}, "vol"));
    assert.equal(res.code, "STARTED");
    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.tripStatus, "started");
    assert.ok(a.startedAt);
  });

  it("only the TravAcser can start the trip (the User cannot)", async () => {
    await db.doc("requests/r1").set({requesterId: "alice", status: "assigned"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "assigned",
      scheduledStartAt: Timestamp.fromMillis(Date.now() - HOUR),
    });
    await assert.rejects(
      () => startTrip(call({requestId: "r1", volunteerId: "vol"}, "alice")),
      /only the travacser/i
    );
  });
});

describe("completeTrip (ends a started trip + bills from startedAt)", () => {
  it("bills from the confirmed startedAt (not scheduledStartAt) and completes the request", async () => {
    await db.doc("requests/r1").set({requesterId: "alice", status: "assigned"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "started",
      startedAt: Timestamp.fromMillis(Date.now() - 100 * 60000), // ~100 min → block 4 (91-120)
      // scheduledStartAt is deliberately earlier — billing must ignore it.
      scheduledStartAt: Timestamp.fromMillis(Date.now() - 3 * HOUR),
    });

    const res: any = await completeTrip(call({requestId: "r1", volunteerId: "vol"}, "vol"));
    assert.equal(res.code, "COMPLETED");
    // 100 min → ceil(100/30)=4 blocks → ₹280 service + ₹100 travel (first) = ₹380.
    assert.equal(res.amountInr, 380);

    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.tripStatus, "completed");
    assert.equal(a.paymentStatus, "pending");
    assert.equal(a.serviceChargeInr, 280);
    assert.equal(a.travelCostInr, 100);

    const r = (await db.doc("requests/r1").get()).data()!;
    assert.equal(r.status, "completed");
    assert.equal(r.travelCostCharged, true);
  });

  it("charges the flat travel cost only once per trip (on the first completion)", async () => {
    await db.doc("requests/r1").set({requesterId: "alice", status: "assigned"});
    const base = {
      requesterId: "alice", tripStatus: "started",
      startedAt: Timestamp.fromMillis(Date.now() - 100 * 60000), // ~100 min → block 4
      scheduledStartAt: Timestamp.fromMillis(Date.now() - 3 * HOUR),
    };
    await db.doc("requests/r1/assignments/v1").set({volunteerId: "v1", ...base});
    await db.doc("requests/r1/assignments/v2").set({volunteerId: "v2", ...base});

    const first: any = await completeTrip(call({requestId: "r1", volunteerId: "v1"}, "v1"));
    assert.equal(first.amountInr, 380); // 280 service + 100 travel

    const second: any = await completeTrip(call({requestId: "r1", volunteerId: "v2"}, "v2"));
    assert.equal(second.amountInr, 280); // 280 service, travel already charged

    const a2 = (await db.doc("requests/r1/assignments/v2").get()).data()!;
    assert.equal(a2.travelCostInr, 0);
    const r = (await db.doc("requests/r1").get()).data()!;
    assert.equal(r.travelCostCharged, true);
    assert.equal(r.status, "completed"); // both done
  });

  it("cannot end a trip that has not been started", async () => {
    await db.doc("requests/r1").set({requesterId: "alice", status: "assigned"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "assigned",
      scheduledStartAt: Timestamp.fromMillis(Date.now() - 2 * HOUR),
    });
    await assert.rejects(
      () => completeTrip(call({requestId: "r1", volunteerId: "vol"}, "vol")),
      /must be started/i
    );
  });

  it("cannot end a started trip before its scheduled start time", async () => {
    await db.doc("requests/r1").set({requesterId: "alice", status: "assigned"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "started",
      startedAt: Timestamp.fromMillis(Date.now() - 5 * 60000), // started early
      scheduledStartAt: Timestamp.fromMillis(Date.now() + HOUR), // not yet due
    });
    await assert.rejects(
      () => completeTrip(call({requestId: "r1", volunteerId: "vol"}, "vol")),
      /before its scheduled start time/i
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
    assert.equal(a.rescheduleStatus, "pending"); // TravAcser must re-confirm
    assert.ok(a.rescheduleDeadlineAt, "a confirm deadline is set");
  });

  it("cannot reschedule once a trip has started (even early)", async () => {
    await db.doc("requests/r1").set({
      requesterId: "alice", status: "assigned", acceptedCount: 1,
      scheduledStartAt: Timestamp.fromMillis(Date.now() + 24 * HOUR),
    });
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "started",
      scheduledStartAt: Timestamp.fromMillis(Date.now() + 24 * HOUR),
    });
    const newMs = Date.now() + 48 * HOUR;
    await assert.rejects(
      () => rescheduleTrip(call({
        requestId: "r1", scheduledDateMs: newMs, startTime: "14:00",
        scheduledStartAtMs: newMs,
      }, "alice")),
      /already started/i
    );
  });
});

describe("respondReschedule", () => {
  async function seedPending(): Promise<void> {
    await db.doc("requests/r1").set({
      requesterId: "alice", status: "assigned", acceptedCount: 1,
    });
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "assigned",
      rescheduleStatus: "pending",
      rescheduleDeadlineAt: Timestamp.fromMillis(Date.now() + HOUR),
    });
  }

  it("continue keeps the slot and clears the pending flag", async () => {
    await seedPending();
    const res: any = await respondReschedule(call({requestId: "r1", accept: true}, "vol"));
    assert.equal(res.code, "CONFIRMED");
    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.rescheduleStatus, "confirmed");
    assert.equal(a.tripStatus, "assigned");
  });

  it("cancel releases the slot and reopens the request", async () => {
    await seedPending();
    const res: any = await respondReschedule(call({requestId: "r1", accept: false}, "vol"));
    assert.equal(res.code, "DECLINED");
    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.tripStatus, "cancelled");
    const r = (await db.doc("requests/r1").get()).data()!;
    assert.equal(r.status, "broadcast");
    assert.equal(r.acceptedCount, 0);
  });

  it("rejects when there is no pending reschedule", async () => {
    await db.doc("requests/r1").set({requesterId: "alice", status: "assigned"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "assigned",
    });
    await assert.rejects(
      () => respondReschedule(call({requestId: "r1", accept: true}, "vol")),
      /no reschedule/i
    );
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

  it("a started trip can no longer be cancelled by either party", async () => {
    await db.doc("requests/r1").set({
      requesterId: "alice", status: "assigned", acceptedCount: 1,
    });
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "started",
    });
    await assert.rejects(
      () => cancelTrip(call({requestId: "r1"}, "alice")), // requester
      /can only be ended/i
    );
    await assert.rejects(
      () => cancelTrip(call({requestId: "r1"}, "vol")), // TravAcser
      /can only be ended/i
    );
    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.equal(a.tripStatus, "started"); // untouched
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

describe("verifyRazorpayPayment", () => {
  it("accepts a valid signature and marks paid; rejects a bad one", async () => {
    process.env.RAZORPAY_KEY_SECRET = "test_secret";
    await db.doc("requests/r1").set({requesterId: "alice"});
    await db.doc("requests/r1/assignments/vol").set({
      volunteerId: "vol", requesterId: "alice", tripStatus: "completed",
      paymentStatus: "pending", amountInr: 270, razorpayOrderId: "order_1",
    });
    const sig = crypto
      .createHmac("sha256", "test_secret")
      .update("order_1|pay_1")
      .digest("hex");

    // Wrong signature is rejected.
    await assert.rejects(
      () => verifyRazorpayPayment(call({
        requestId: "r1", volunteerId: "vol", razorpayOrderId: "order_1",
        razorpayPaymentId: "pay_1", razorpaySignature: "deadbeef",
      }, "alice")),
      /verified/i
    );

    // Correct signature marks the trip paid.
    const res: any = await verifyRazorpayPayment(call({
      requestId: "r1", volunteerId: "vol", razorpayOrderId: "order_1",
      razorpayPaymentId: "pay_1", razorpaySignature: sig,
    }, "alice"));
    assert.equal(res.code, "PAID");
    const a = (await db.doc("requests/r1/assignments/vol").get()).data()!;
    assert.ok(a.requesterPaidAt);
    assert.equal(a.razorpayPaymentId, "pay_1");
    assert.equal(a.paymentStatus, "awaiting_other");
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

describe("logManualTrip (admin gate)", () => {
  it("an admin logs a manual trip; a non-admin is denied", async () => {
    await assert.rejects(
      () => logManualTrip(call({
        userDetails: "Bob 999", travAcserDetails: "Vic 888",
        tripDateMs: Date.now(),
      }, "mallory")),
      /admin/i
    );

    const res: any = await logManualTrip(call({
      userDetails: "Bob 999", travAcserDetails: "Vic 888",
      tripDateMs: Date.now(), note: "phone booking",
    }, "root", {admin: true}));
    assert.equal(res.code, "LOGGED");
    const log = (await db.doc(`tripLogs/${res.id}`).get()).data()!;
    assert.equal(log.source, "manual");
    assert.equal(log.userDetails, "Bob 999");
    assert.equal(log.createdBy, "root");
  });
});
