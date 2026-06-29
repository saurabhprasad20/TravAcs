import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";

initializeApp();
const db = getFirestore();

const REGION = "asia-south2";
const HOURLY_RATE_INR = 135;

/** Sends a data+notification message to all of a user's device tokens. */
async function pushToUser(
  uid: string,
  notification: {title: string; body: string},
  data: Record<string, string>
): Promise<void> {
  const toks = await db.collection("devices").doc(uid).collection("tokens").get();
  if (toks.empty) return;
  const tokens = toks.docs.map((t) => t.id);
  const resp = await getMessaging().sendEachForMulticast({
    tokens,
    notification,
    data,
    android: {priority: "high"},
  });
  const deletions: Promise<unknown>[] = [];
  resp.responses.forEach((r, i) => {
    if (
      !r.success &&
      (r.error?.code === "messaging/registration-token-not-registered" ||
        r.error?.code === "messaging/invalid-registration-token")
    ) {
      deletions.push(toks.docs[i].ref.delete());
    }
  });
  await Promise.all(deletions);
}

/**
 * When a request is created with status "broadcast", notify approved + active
 * TravAcsers in the SAME city (region-scoped fan-out). OTP is NOT minted here —
 * it is created at assignment (M4/M5).
 */
export const onRequestCreated = onDocumentCreated(
  "requests/{id}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const req = snap.data();
    if (!req || req.status !== "broadcast") return;

    const city: string | undefined = req.serviceCity;
    if (!city) return;

    // Approved, active TravAcsers in the same city.
    const vols = await db
      .collection("profiles")
      .where("role", "==", "volunteer")
      .where("verificationStatus", "==", "approved")
      .where("isActive", "==", true)
      .where("serviceCity", "==", city)
      .get();

    if (vols.empty) {
      logger.info(`No TravAcsers in city=${city} for request ${event.params.id}`);
      return;
    }

    // Gather their device tokens.
    const tokens: string[] = [];
    const refByToken: Record<string, FirebaseFirestore.DocumentReference> = {};
    for (const v of vols.docs) {
      const toks = await db
        .collection("devices")
        .doc(v.id)
        .collection("tokens")
        .get();
      toks.forEach((t) => {
        tokens.push(t.id);
        refByToken[t.id] = t.ref;
      });
    }
    if (tokens.length === 0) {
      logger.info(`No device tokens for city=${city}`);
      return;
    }

    const travellers = req.numTravellers ?? 1;
    const resp = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "New assistance request",
        body: `A new request in your city · ${travellers} traveller(s)`,
      },
      data: {
        type: "new_request",
        requestId: event.params.id,
      },
      android: {priority: "high"},
    });

    // Prune tokens that are no longer valid.
    const deletions: Promise<unknown>[] = [];
    resp.responses.forEach((r, i) => {
      if (!r.success) {
        const code = r.error?.code;
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          deletions.push(refByToken[tokens[i]].delete());
        }
      }
    });
    await Promise.all(deletions);

    logger.info(
      `Notified ${resp.successCount}/${tokens.length} devices in ${city} ` +
        `for request ${event.params.id}`
    );
  }
);

/**
 * A TravAcser claims a slot on a request (slot-filling FCFS). A transaction
 * guarantees a request is never over-subscribed. Each acceptance creates a
 * per-TravAcser assignment (with the contact pair) and a private OTP the User
 * shares at meet-up (the TravAcser cannot read it).
 */
export const acceptRequest = onCall({region: REGION}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
  const requestId: string | undefined = req.data?.requestId;
  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }

  // Caller must be an approved, active TravAcser (stable; read outside the tx).
  const volSnap = await db.collection("profiles").doc(uid).get();
  const vol = volSnap.data();
  if (
    !vol ||
    vol.role !== "volunteer" ||
    vol.verificationStatus !== "approved" ||
    vol.isActive !== true
  ) {
    throw new HttpsError("permission-denied", "Your account is not an approved, active TravAcser.", {code: "NOT_APPROVED"});
  }

  const reqRef = db.collection("requests").doc(requestId);
  const assignRef = reqRef.collection("assignments").doc(uid);

  const out = await db.runTransaction(async (tx) => {
    // ---- all reads first ----
    const reqDoc = await tx.get(reqRef);
    if (!reqDoc.exists) {
      throw new HttpsError("not-found", "Request not found.");
    }
    const r = reqDoc.data() as FirebaseFirestore.DocumentData;
    if (r.status !== "broadcast") {
      throw new HttpsError("failed-precondition", "This request is no longer open.", {code: "ALREADY_TAKEN"});
    }
    if (r.serviceCity !== vol.serviceCity) {
      throw new HttpsError("failed-precondition", "This request is in another city.", {code: "WRONG_CITY"});
    }
    const existing = await tx.get(assignRef);
    if (existing.exists) {
      throw new HttpsError("already-exists", "You have already accepted this request.", {code: "ALREADY_ACCEPTED"});
    }
    const need: number = r.numTravAcsers ?? 1;
    const accepted: number = r.acceptedCount ?? 0;
    if (accepted >= need) {
      throw new HttpsError("failed-precondition", "All TravAcser slots are filled.", {code: "ALREADY_TAKEN"});
    }
    const reqProfile = (await tx.get(db.collection("profiles").doc(r.requesterId))).data() || {};

    // ---- writes ----
    const perTravAcserInr = Math.round(
      ((r.expectedDurationMinutes ?? 60) / 60) * HOURLY_RATE_INR
    );
    tx.set(assignRef, {
      volunteerId: uid,
      volunteerName: vol.fullName ?? "",
      volunteerPhone: vol.phone ?? null,
      requesterId: r.requesterId,
      requesterName: r.requesterName ?? reqProfile.fullName ?? "",
      requesterPhone: reqProfile.phone ?? null,
      acceptedAt: FieldValue.serverTimestamp(),
      // denormalized request summary for the TravAcser's My Trips list
      scheduledDate: r.scheduledDate ?? null,
      startTime: r.startTime ?? "",
      expectedDurationMinutes: r.expectedDurationMinutes ?? 60,
      meetingPoint: r.meetingPoint ?? "",
      destination: r.destination ?? "",
      genderPreference: r.genderPreference ?? "any_gender",
      scheduledStartAt: r.scheduledStartAt ?? null,
      numTravellers: r.numTravellers ?? 1,
      amountInrEstimate: perTravAcserInr,
      tripStatus: "assigned",
    });
    const newCount = accepted + 1;
    tx.update(reqRef, {
      acceptedCount: newCount,
      status: newCount >= need ? "assigned" : "broadcast",
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {requesterId: r.requesterId, filled: newCount, need};
  });

  // Notify the requester (best-effort).
  await pushToUser(
    out.requesterId,
    {
      title: "A TravAcser accepted your request",
      body: `${out.filled} of ${out.need} TravAcser(s) confirmed.`,
    },
    {type: "assignment", requestId, filled: String(out.filled)}
  ).catch((e) => logger.warn("push failed", e));

  return {ok: true, code: "ACCEPTED", slotsRemaining: out.need - out.filled};
});

/**
 * Ends/completes a TravAcser's trip (by that TravAcser or the requester). Trips
 * auto-start at their scheduled time (no OTP), so billing is anchored to
 * `scheduledStartAt`. When no active assignment remains, the request is
 * marked completed.
 */
export const completeTrip = onCall({region: REGION}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
  const requestId: string | undefined = req.data?.requestId;
  const volunteerId: string | undefined = req.data?.volunteerId;
  if (!requestId || !volunteerId) {
    throw new HttpsError("invalid-argument", "requestId and volunteerId are required.");
  }

  const reqRef = db.collection("requests").doc(requestId);
  const assignRef = reqRef.collection("assignments").doc(volunteerId);

  const out = await db.runTransaction(async (tx) => {
    const reqDoc = await tx.get(reqRef);
    if (!reqDoc.exists) throw new HttpsError("not-found", "Request not found.");
    const r = reqDoc.data() as FirebaseFirestore.DocumentData;
    // Authorize: the TravAcser themselves or the requester.
    if (uid !== volunteerId && uid !== r.requesterId) {
      throw new HttpsError("permission-denied", "You cannot complete this trip.");
    }
    const assignDoc = await tx.get(assignRef);
    if (!assignDoc.exists) throw new HttpsError("not-found", "Assignment not found.");
    const a = assignDoc.data() as FirebaseFirestore.DocumentData;
    if (a.tripStatus !== "assigned") {
      throw new HttpsError("failed-precondition", "This trip can no longer be ended.", {code: "INVALID_STATE"});
    }
    // Auto-start by time: the trip is "in progress" once scheduledStartAt has
    // passed; billing is anchored there.
    const startAt: FirebaseFirestore.Timestamp | undefined = a.scheduledStartAt;
    const startMs = startAt ? startAt.toMillis() : Date.now();
    if (Date.now() < startMs) {
      throw new HttpsError("failed-precondition", "This trip has not started yet.", {code: "NOT_STARTED"});
    }
    const minutes = Math.max(1, Math.round((Date.now() - startMs) / 60000));
    const amountInr = Math.round((minutes / 60) * HOURLY_RATE_INR);
    tx.update(assignRef, {
      tripStatus: "completed",
      startedAt: startAt ?? FieldValue.serverTimestamp(),
      endedAt: FieldValue.serverTimestamp(),
      durationMinutes: minutes,
      amountInr,
      paymentStatus: "pending",
    });
    return {requesterId: r.requesterId, amountInr};
  });

  // Mark the request completed once no active assignment remains.
  const assignsSnap = await reqRef.collection("assignments").get();
  const statuses = assignsSnap.docs.map((d) => d.data().tripStatus);
  const anyActive = statuses.some((s) => s === "assigned" || s === "started");
  const anyCompleted = statuses.some((s) => s === "completed" || s === "closed");
  if (!anyActive && anyCompleted) {
    await reqRef.update({status: "completed", updatedAt: FieldValue.serverTimestamp()});
  }

  // Notify both parties.
  await Promise.all([
    pushToUser(out.requesterId, {title: "Trip completed", body: `Amount: ₹${out.amountInr}.`}, {type: "trip_completed", requestId}).catch(() => {}),
    pushToUser(volunteerId, {title: "Trip completed", body: `You earned ₹${out.amountInr}.`}, {type: "trip_completed", requestId}).catch(() => {}),
  ]);

  return {ok: true, code: "COMPLETED", amountInr: out.amountInr};
});

/**
 * The User reschedules a trip (new date + time) before it starts. Updates the
 * request and every still-assigned assignment with the new schedule.
 */
export const rescheduleTrip = onCall({region: REGION}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
  const {requestId, scheduledDateMs, startTime, scheduledStartAtMs} = req.data ?? {};
  if (
    !requestId ||
    typeof scheduledDateMs !== "number" ||
    typeof scheduledStartAtMs !== "number" ||
    !startTime
  ) {
    throw new HttpsError("invalid-argument", "requestId, scheduledDateMs, startTime, scheduledStartAtMs required.");
  }

  const reqRef = db.collection("requests").doc(requestId);
  const volunteerIds: string[] = [];
  await db.runTransaction(async (tx) => {
    const reqDoc = await tx.get(reqRef);
    const r = reqDoc.data();
    if (!r) throw new HttpsError("not-found", "Request not found.");
    if (r.requesterId !== uid) {
      throw new HttpsError("permission-denied", "Only the User can reschedule.");
    }
    if (r.status !== "broadcast" && r.status !== "assigned") {
      throw new HttpsError("failed-precondition", "This trip can no longer be rescheduled.", {code: "INVALID_STATE"});
    }
    const existingStart: FirebaseFirestore.Timestamp | undefined = r.scheduledStartAt;
    if (existingStart && Date.now() >= existingStart.toMillis()) {
      throw new HttpsError("failed-precondition", "The trip has already started.", {code: "ALREADY_STARTED"});
    }
    const assigns = await tx.get(reqRef.collection("assignments"));
    const newDate = Timestamp.fromMillis(scheduledDateMs);
    const newStartAt = Timestamp.fromMillis(scheduledStartAtMs);
    tx.update(reqRef, {
      scheduledDate: newDate,
      startTime,
      scheduledStartAt: newStartAt,
      updatedAt: FieldValue.serverTimestamp(),
    });
    assigns.docs.forEach((d) => {
      if (d.data().tripStatus === "assigned") {
        volunteerIds.push(d.id);
        tx.update(d.ref, {scheduledDate: newDate, startTime, scheduledStartAt: newStartAt});
      }
    });
  });

  await Promise.all(
    volunteerIds.map((v) =>
      pushToUser(v, {title: "Trip rescheduled", body: "The User changed the trip time."}, {type: "trip_rescheduled", requestId}).catch(() => {})
    )
  );
  return {ok: true, code: "RESCHEDULED"};
});

/**
 * Cancel after acceptance. The caller's role is inferred: a requester cancels
 * the whole request (and all active assignments); a TravAcser releases just
 * their own slot (which reopens the request if it was full).
 */
export const cancelTrip = onCall({region: REGION}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
  const {requestId} = req.data ?? {};
  if (!requestId) throw new HttpsError("invalid-argument", "requestId required.");

  const reqRef = db.collection("requests").doc(requestId);
  const notify: {uid: string; title: string; body: string}[] = [];
  await db.runTransaction(async (tx) => {
    const reqDoc = await tx.get(reqRef);
    const r = reqDoc.data();
    if (!r) throw new HttpsError("not-found", "Request not found.");
    if (r.status === "completed" || r.status === "cancelled") {
      throw new HttpsError("failed-precondition", "This trip can no longer be cancelled.", {code: "INVALID_STATE"});
    }
    const assigns = await tx.get(reqRef.collection("assignments"));
    const isRequester = r.requesterId === uid;
    const myAssign = assigns.docs.find((d) => d.id === uid);
    if (!isRequester && !myAssign) {
      throw new HttpsError("permission-denied", "You are not part of this trip.");
    }

    if (isRequester) {
      tx.update(reqRef, {status: "cancelled", updatedAt: FieldValue.serverTimestamp()});
      assigns.docs.forEach((d) => {
        const s = d.data().tripStatus;
        if (s === "assigned" || s === "started") {
          tx.update(d.ref, {tripStatus: "cancelled"});
          notify.push({uid: d.id, title: "Trip cancelled", body: "The User cancelled the trip."});
        }
      });
    } else {
      const s = myAssign!.data().tripStatus;
      if (s !== "assigned" && s !== "started") {
        throw new HttpsError("failed-precondition", "This trip can no longer be cancelled.", {code: "INVALID_STATE"});
      }
      tx.update(myAssign!.ref, {tripStatus: "cancelled"});
      const accepted: number = r.acceptedCount ?? 0;
      tx.update(reqRef, {
        acceptedCount: Math.max(0, accepted - 1),
        // Reopen for others if it had been filled.
        status: r.status === "assigned" ? "broadcast" : r.status,
        updatedAt: FieldValue.serverTimestamp(),
      });
      notify.push({uid: r.requesterId, title: "A TravAcser cancelled", body: "A TravAcser cancelled their assignment."});
    }
  });

  await Promise.all(
    notify.map((n) =>
      pushToUser(n.uid, {title: n.title, body: n.body}, {type: "trip_cancelled", requestId}).catch(() => {})
    )
  );
  return {ok: true, code: "CANCELLED"};
});

/** Recomputes paymentStatus from the two timestamps. */
function paymentStatusOf(paid: unknown, received: unknown): string {
  if (paid && received) return "confirmed";
  if (paid || received) return "awaiting_other";
  return "pending";
}

/** The User marks they have paid a TravAcser (external UPI). */
export const markPaid = onCall({region: REGION}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
  const {requestId, volunteerId} = req.data ?? {};
  if (!requestId || !volunteerId) {
    throw new HttpsError("invalid-argument", "requestId and volunteerId required.");
  }
  const reqRef = db.collection("requests").doc(requestId);
  const assignRef = reqRef.collection("assignments").doc(volunteerId);
  await db.runTransaction(async (tx) => {
    const reqDoc = await tx.get(reqRef);
    if (reqDoc.data()?.requesterId !== uid) {
      throw new HttpsError("permission-denied", "Only the User can mark Paid.");
    }
    const a = (await tx.get(assignRef)).data();
    if (!a) throw new HttpsError("not-found", "Assignment not found.");
    if (a.tripStatus !== "completed") {
      throw new HttpsError("failed-precondition", "The trip is not completed yet.", {code: "INVALID_STATE"});
    }
    tx.update(assignRef, {
      requesterPaidAt: a.requesterPaidAt ?? FieldValue.serverTimestamp(),
      paymentStatus: paymentStatusOf(true, a.travAcserReceivedAt),
    });
  });
  await pushToUser(volunteerId, {title: "Payment marked", body: "The User marked the payment as Paid."}, {type: "payment_marked", requestId}).catch(() => {});
  return {ok: true, code: "PAID"};
});

/** The TravAcser marks they received payment. */
export const markReceived = onCall({region: REGION}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
  const {requestId} = req.data ?? {};
  if (!requestId) throw new HttpsError("invalid-argument", "requestId required.");
  const reqRef = db.collection("requests").doc(requestId);
  const assignRef = reqRef.collection("assignments").doc(uid);
  let requesterId: string | undefined;
  await db.runTransaction(async (tx) => {
    const a = (await tx.get(assignRef)).data();
    if (!a) throw new HttpsError("not-found", "You have no assignment here.");
    if (a.tripStatus !== "completed") {
      throw new HttpsError("failed-precondition", "The trip is not completed yet.", {code: "INVALID_STATE"});
    }
    requesterId = a.requesterId;
    tx.update(assignRef, {
      travAcserReceivedAt: a.travAcserReceivedAt ?? FieldValue.serverTimestamp(),
      paymentStatus: paymentStatusOf(a.requesterPaidAt, true),
    });
  });
  if (requesterId) {
    await pushToUser(requesterId, {title: "Payment confirmed", body: "The TravAcser marked the payment as Received."}, {type: "payment_marked", requestId}).catch(() => {});
  }
  return {ok: true, code: "RECEIVED"};
});

/** Mutual rating (User↔TravAcser) for a completed assignment. */
export const submitRating = onCall({region: REGION}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
  const {requestId, volunteerId, stars, feedback} = req.data ?? {};
  if (!requestId || !volunteerId || typeof stars !== "number") {
    throw new HttpsError("invalid-argument", "requestId, volunteerId, stars required.");
  }
  if (stars < 1 || stars > 5) {
    throw new HttpsError("invalid-argument", "Stars must be 1–5.");
  }
  const reqRef = db.collection("requests").doc(requestId);
  const assignRef = reqRef.collection("assignments").doc(volunteerId);

  await db.runTransaction(async (tx) => {
    const reqDoc = await tx.get(reqRef);
    const r = reqDoc.data();
    if (!r) throw new HttpsError("not-found", "Request not found.");
    const a = (await tx.get(assignRef)).data();
    if (!a) throw new HttpsError("not-found", "Assignment not found.");
    if (a.tripStatus !== "completed") {
      throw new HttpsError("failed-precondition", "Rate after the trip is completed.", {code: "INVALID_STATE"});
    }
    // Who is rating whom?
    let raterRole: "requester" | "volunteer";
    let rateeId: string;
    if (uid === r.requesterId) {
      raterRole = "requester";
      rateeId = volunteerId; // User rates the TravAcser
    } else if (uid === volunteerId) {
      raterRole = "volunteer";
      rateeId = r.requesterId; // TravAcser rates the User
    } else {
      throw new HttpsError("permission-denied", "You are not a party to this trip.");
    }
    const alreadyKey = raterRole === "requester" ? "requesterRatingStars" : "volunteerRatingStars";
    if (a[alreadyKey] != null) {
      throw new HttpsError("already-exists", "You have already rated.", {code: "ALREADY_RATED"});
    }
    // Update ratee profile aggregate.
    const rateeRef = db.collection("profiles").doc(rateeId);
    const ratee = (await tx.get(rateeRef)).data() ?? {};
    const count: number = ratee.ratingCount ?? 0;
    const avg: number = ratee.ratingAvg ?? 0;
    const newCount = count + 1;
    const newAvg = Math.round(((avg * count + stars) / newCount) * 10) / 10;
    tx.update(rateeRef, {ratingAvg: newAvg, ratingCount: newCount});
    // Write the rating onto the assignment.
    const fields = raterRole === "requester"
      ? {requesterRatingStars: stars, requesterRatingFeedback: feedback ?? null}
      : {volunteerRatingStars: stars, volunteerRatingFeedback: feedback ?? null};
    tx.update(assignRef, fields);
  });
  return {ok: true, code: "RATED"};
});

/** Admin approves/rejects a TravAcser (admin custom claim required). */
export const setVerification = onCall({region: REGION}, async (req) => {
  if (req.auth?.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin only.");
  }
  const {uid, decision, reason} = req.data ?? {};
  if (!uid || (decision !== "approved" && decision !== "rejected")) {
    throw new HttpsError("invalid-argument", "uid and decision (approved|rejected) required.");
  }
  const ref = db.collection("profiles").doc(uid);
  const snap = await ref.get();
  if (!snap.exists || snap.data()?.role !== "volunteer") {
    throw new HttpsError("not-found", "TravAcser not found.");
  }
  await ref.update({
    verificationStatus: decision,
    verifiedBy: req.auth!.uid,
    verifiedAt: FieldValue.serverTimestamp(),
    rejectionReason: decision === "rejected" ? (reason ?? null) : FieldValue.delete(),
  });
  await pushToUser(
    uid,
    {
      title: decision === "approved" ? "You're verified" : "Verification update",
      body: decision === "approved"
        ? "You can now view and accept requests."
        : `Your verification was not approved${reason ? ": " + reason : "."}`,
    },
    {type: "verification_result", decision}
  ).catch(() => {});
  return {ok: true, code: decision.toUpperCase()};
});
