import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {defineSecret} from "firebase-functions/params";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as crypto from "crypto";

initializeApp();
const db = getFirestore();

// Razorpay API credentials — set via `firebase functions:secrets:set`. The
// secret NEVER ships to the client; the client only receives the order id + key
// id from createRazorpayOrder at runtime.
const RAZORPAY_KEY_ID = defineSecret("RAZORPAY_KEY_ID");
const RAZORPAY_KEY_SECRET = defineSecret("RAZORPAY_KEY_SECRET");

const REGION = "asia-south2";
// Cloud Scheduler is not offered in asia-south2 (Delhi), so the two scheduled
// functions run in asia-south1 (Mumbai). Callables stay in asia-south2 to match
// the client (functionsProvider).
const SCHEDULER_REGION = "asia-south1";
const HOURLY_RATE_INR = 135;
/** India Standard Time offset (UTC+5:30) in milliseconds. */
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

/**
 * Calendar-date key (YYYY-M-D) for a timestamp in IST, used to compare whether
 * two trips fall on the "same day" for the caller. Returns null for a missing
 * timestamp.
 */
function istDateKey(
  ts: FirebaseFirestore.Timestamp | undefined | null
): string | null {
  if (!ts) return null;
  const d = new Date(ts.toMillis() + IST_OFFSET_MS);
  return `${d.getUTCFullYear()}-${d.getUTCMonth() + 1}-${d.getUTCDate()}`;
}

/** Max tokens per sendEachForMulticast call (Admin SDK hard limit). */
const FCM_BATCH = 500;

/**
 * Sends a multicast message to many tokens, chunked to the Admin SDK's 500-token
 * limit (a single call rejects beyond that), and prunes tokens the FCM backend
 * reports as permanently invalid. `refByToken` maps each token to its Firestore
 * doc ref so dead tokens can be deleted.
 */
async function sendMulticastChunked(
  tokens: string[],
  refByToken: Record<string, FirebaseFirestore.DocumentReference>,
  notification: {title: string; body: string},
  data: Record<string, string>
): Promise<number> {
  const unique = Array.from(new Set(tokens));
  let successCount = 0;
  const deletions: Promise<unknown>[] = [];
  for (let i = 0; i < unique.length; i += FCM_BATCH) {
    const batch = unique.slice(i, i + FCM_BATCH);
    const resp = await getMessaging().sendEachForMulticast({
      tokens: batch,
      notification,
      data,
      android: {priority: "high"},
    });
    successCount += resp.successCount;
    resp.responses.forEach((r, j) => {
      if (
        !r.success &&
        (r.error?.code === "messaging/registration-token-not-registered" ||
          r.error?.code === "messaging/invalid-registration-token")
      ) {
        const ref = refByToken[batch[j]];
        if (ref) deletions.push(ref.delete());
      }
    });
  }
  await Promise.all(deletions);
  return successCount;
}

/** Sends a data+notification message to all of a user's device tokens. */
async function pushToUser(
  uid: string,
  notification: {title: string; body: string},
  data: Record<string, string>
): Promise<void> {
  const toks = await db.collection("devices").doc(uid).collection("tokens").get();
  if (toks.empty) return;
  const tokens: string[] = [];
  const refByToken: Record<string, FirebaseFirestore.DocumentReference> = {};
  toks.docs.forEach((t) => {
    tokens.push(t.id);
    refByToken[t.id] = t.ref;
  });
  await sendMulticastChunked(tokens, refByToken, notification, data);
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
    const successCount = await sendMulticastChunked(
      tokens,
      refByToken,
      {
        title: "New assistance request",
        body: `A new request in your city · ${travellers} traveller(s)`,
      },
      {
        type: "new_request",
        requestId: event.params.id,
      }
    );

    logger.info(
      `Notified ${successCount}/${tokens.length} devices in ${city} ` +
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
      // A previously cancelled/declined/expired assignment leaves a doc behind;
      // that must NOT block re-accepting a request that reopened to the feed.
      // Only a still-live assignment (assigned/started/completed) counts as
      // "already accepted".
      const prevStatus = existing.data()?.tripStatus;
      const stillLive =
        prevStatus === "assigned" ||
        prevStatus === "started" ||
        prevStatus === "completed" ||
        prevStatus === "closed";
      if (stillLive) {
        throw new HttpsError("already-exists", "You have already accepted this request.", {code: "ALREADY_ACCEPTED"});
      }
    }
    const need: number = r.numTravAcsers ?? 1;
    const accepted: number = r.acceptedCount ?? 0;
    if (accepted >= need) {
      throw new HttpsError("failed-precondition", "All TravAcser slots are filled.", {code: "ALREADY_TAKEN"});
    }
    const reqProfile = (await tx.get(db.collection("profiles").doc(r.requesterId))).data() || {};

    // One accepted trip per day: reject if the caller already has an active
    // assignment (assigned/started) on the SAME calendar date (IST) as this
    // request. Read inside the transaction so all reads precede the writes.
    const targetDay = istDateKey(r.scheduledStartAt);
    if (targetDay) {
      const mine = await tx.get(
        db.collectionGroup("assignments").where("volunteerId", "==", uid)
      );
      const clash = mine.docs.some((d) => {
        const ad = d.data();
        const active = ad.tripStatus === "assigned" || ad.tripStatus === "started";
        return active && istDateKey(ad.scheduledStartAt) === targetDay;
      });
      if (clash) {
        throw new HttpsError(
          "failed-precondition",
          "You can't accept more than one trip on a day.",
          {code: "ONE_PER_DAY"}
        );
      }
    }

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
 * Starts a trip after the TravAcser validates the User's start code. The code is
 * deterministic + validated entirely on the clients (offline); this callable
 * ONLY records the status flip. TravAcser-only (they are the one who enters and
 * validates the User's code). The trip may start early (the parties often meet
 * before the scheduled time) — billing runs from the recorded `startedAt`. The
 * User is notified so both sides see "trip started".
 */
export const startTrip = onCall({region: REGION}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
  const {requestId, volunteerId} = req.data ?? {};
  if (!requestId || !volunteerId) {
    throw new HttpsError("invalid-argument", "requestId and volunteerId are required.");
  }
  if (uid !== volunteerId) {
    throw new HttpsError("permission-denied", "Only the TravAcser can start the trip.");
  }
  const reqRef = db.collection("requests").doc(requestId);
  const assignRef = reqRef.collection("assignments").doc(volunteerId);
  let requesterId: string | undefined;
  await db.runTransaction(async (tx) => {
    const reqDoc = await tx.get(reqRef);
    const r = reqDoc.data();
    if (!r) throw new HttpsError("not-found", "Request not found.");
    requesterId = r.requesterId;
    const a = (await tx.get(assignRef)).data();
    if (!a) throw new HttpsError("not-found", "Assignment not found.");
    if (a.volunteerId !== uid) {
      throw new HttpsError("permission-denied", "This is not your trip.");
    }
    if (a.tripStatus !== "assigned") {
      throw new HttpsError("failed-precondition", "This trip can no longer be started.", {code: "INVALID_STATE"});
    }
    tx.update(assignRef, {
      tripStatus: "started",
      startedAt: FieldValue.serverTimestamp(),
      otpStartedAt: FieldValue.serverTimestamp(),
    });
  });
  // Notify the User that their code was validated and the trip has started.
  if (requesterId) {
    await pushToUser(
      requesterId,
      {title: "Trip started", body: "Your TravAcser validated your start code — the trip is now in progress."},
      {type: "trip_started", requestId}
    ).catch(() => {});
  }
  return {ok: true, code: "STARTED"};
});

/**
 * Ends/completes a TravAcser's trip (by that TravAcser or the requester). The
 * trip must have been started (the TravAcser validated the User's start code),
 * so billing is anchored to the recorded `startedAt`. When no active assignment
 * remains, the request is marked completed.
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
    if (a.tripStatus !== "started") {
      throw new HttpsError("failed-precondition", "This trip must be started before it can be ended.", {code: "NOT_STARTED"});
    }
    const startedAt: FirebaseFirestore.Timestamp | undefined = a.startedAt;
    const scheduledStart: FirebaseFirestore.Timestamp | undefined = a.scheduledStartAt;
    // A trip may START early (the parties meet sooner), but it can never be
    // ENDED before its scheduled start time. Skip only if the schedule anchor is
    // somehow missing on a legacy doc.
    if (scheduledStart && Date.now() < scheduledStart.toMillis()) {
      throw new HttpsError("failed-precondition", "This trip can't be ended before its scheduled start time.", {code: "EARLY_END"});
    }
    // Bill from the actual start the User confirmed (recorded by startTrip),
    // falling back to the scheduled start only if startedAt is somehow missing.
    const startMs =
      startedAt?.toMillis() ?? scheduledStart?.toMillis() ?? Date.now();
    const minutes = Math.max(1, Math.round((Date.now() - startMs) / 60000));
    const amountInr = Math.round((minutes / 60) * HOURLY_RATE_INR);
    tx.update(assignRef, {
      tripStatus: "completed",
      startedAt: startedAt ?? FieldValue.serverTimestamp(),
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

  // Notify both parties that the trip ended. This is NOT a payment
  // notification — the amount is only "pending" here; the actual payment
  // notifications are sent from markPaid / markReceived once the User pays.
  await Promise.all([
    pushToUser(out.requesterId, {title: "Trip ended", body: `Amount due: ₹${out.amountInr} (payment pending). Mark it paid once you pay.`}, {type: "trip_completed", requestId}).catch(() => {}),
    pushToUser(volunteerId, {title: "Trip ended", body: `Amount ₹${out.amountInr} — payment pending from the User.`}, {type: "trip_completed", requestId}).catch(() => {}),
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
  // The new start must be a bounded future time — reject past or absurd values a
  // tampered client could send.
  const nowMs = Date.now();
  if (
    scheduledStartAtMs < nowMs + 60000 ||
    scheduledStartAtMs > nowMs + 90 * 24 * 60 * 60000
  ) {
    throw new HttpsError("invalid-argument", "The new trip time must be in the future (within 90 days).", {code: "BAD_SCHEDULE"});
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
    // A trip is "started" only if it was accepted AND its time has arrived. An
    // unaccepted (acceptedCount 0) request never starts on time alone, so it
    // stays reschedulable even if its original time has passed.
    const accepted: number = r.acceptedCount ?? 0;
    if (accepted > 0 && existingStart && Date.now() >= existingStart.toMillis()) {
      throw new HttpsError("failed-precondition", "The trip has already started.", {code: "ALREADY_STARTED"});
    }
    const assigns = await tx.get(reqRef.collection("assignments"));
    // A trip that has actually started (even early, before its scheduled time)
    // can only be ended — never rescheduled.
    if (assigns.docs.some((d) => d.data().tripStatus === "started")) {
      throw new HttpsError("failed-precondition", "The trip has already started.", {code: "ALREADY_STARTED"});
    }
    const newDate = Timestamp.fromMillis(scheduledDateMs);
    const newStartAt = Timestamp.fromMillis(scheduledStartAtMs);
    // Each still-assigned TravAcser must re-confirm the new time. They get up to
    // 10% of the remaining time (now → new start) to respond before the slot is
    // auto-released and the request reopens (enforced by
    // expireRescheduleConfirmations).
    const remainingMs = Math.max(0, scheduledStartAtMs - Date.now());
    const rescheduleDeadlineAt = Timestamp.fromMillis(
      Date.now() + Math.round(remainingMs * 0.1)
    );
    tx.update(reqRef, {
      scheduledDate: newDate,
      startTime,
      scheduledStartAt: newStartAt,
      // Let the "no TravAcser found" warning fire again for the new time.
      noTravAcserNotifiedAt: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    assigns.docs.forEach((d) => {
      if (d.data().tripStatus === "assigned") {
        volunteerIds.push(d.id);
        tx.update(d.ref, {
          scheduledDate: newDate,
          startTime,
          scheduledStartAt: newStartAt,
          rescheduleStatus: "pending",
          rescheduleDeadlineAt,
        });
      }
    });
  });

  await Promise.all(
    volunteerIds.map((v) =>
      pushToUser(v, {title: "Trip rescheduled", body: "The User changed the trip time. Open TravAcs to continue or cancel."}, {type: "trip_rescheduled", requestId}).catch(() => {})
    )
  );
  return {ok: true, code: "RESCHEDULED"};
});

/**
 * A TravAcser responds to a rescheduled trip: continue (keep the slot) or
 * cancel (release it and reopen the request to the feed).
 */
export const respondReschedule = onCall({region: REGION}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
  const {requestId, accept} = req.data ?? {};
  if (!requestId || typeof accept !== "boolean") {
    throw new HttpsError("invalid-argument", "requestId and accept (bool) required.");
  }
  const reqRef = db.collection("requests").doc(requestId);
  const assignRef = reqRef.collection("assignments").doc(uid);
  let requesterId: string | undefined;
  await db.runTransaction(async (tx) => {
    const reqDoc = await tx.get(reqRef);
    const r = reqDoc.data();
    if (!r) throw new HttpsError("not-found", "Request not found.");
    requesterId = r.requesterId;
    const a = (await tx.get(assignRef)).data();
    if (!a) throw new HttpsError("not-found", "You have no assignment here.");
    if (a.rescheduleStatus !== "pending") {
      throw new HttpsError("failed-precondition", "There is no reschedule to respond to.", {code: "NO_PENDING"});
    }
    if (accept) {
      tx.update(assignRef, {
        rescheduleStatus: "confirmed",
        rescheduleDeadlineAt: FieldValue.delete(),
      });
    } else {
      tx.update(assignRef, {
        tripStatus: "cancelled",
        rescheduleStatus: "declined",
        rescheduleDeadlineAt: FieldValue.delete(),
      });
      const accepted: number = r.acceptedCount ?? 0;
      tx.update(reqRef, {
        acceptedCount: Math.max(0, accepted - 1),
        status: r.status === "assigned" ? "broadcast" : r.status,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });
  if (!accept && requesterId) {
    await pushToUser(requesterId, {title: "A TravAcser declined the new time", body: "A TravAcser couldn't make the rescheduled trip, so we've reopened your request."}, {type: "trip_cancelled", requestId}).catch(() => {});
  }
  return {ok: true, code: accept ? "CONFIRMED" : "DECLINED"};
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
      // A started trip can only be ended, never cancelled.
      if (assigns.docs.some((d) => d.data().tripStatus === "started")) {
        throw new HttpsError("failed-precondition", "A started trip can't be cancelled — it can only be ended.", {code: "TRIP_STARTED"});
      }
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
      if (s === "started") {
        throw new HttpsError("failed-precondition", "A started trip can't be cancelled — it can only be ended.", {code: "TRIP_STARTED"});
      }
      if (s !== "assigned") {
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

/**
 * Creates a Razorpay order for a completed assignment's amount and returns the
 * order id + key id so the client can open the Razorpay checkout. Requester
 * only. The Key Secret stays server-side (Secret Manager).
 */
export const createRazorpayOrder = onCall(
  {region: REGION, secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET]},
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
    const {requestId, volunteerId} = req.data ?? {};
    if (!requestId || !volunteerId) {
      throw new HttpsError("invalid-argument", "requestId and volunteerId required.");
    }
    const reqRef = db.collection("requests").doc(requestId);
    const assignRef = reqRef.collection("assignments").doc(volunteerId);
    const [reqSnap, aSnap] = await Promise.all([reqRef.get(), assignRef.get()]);
    const r = reqSnap.data();
    const a = aSnap.data();
    if (!r || !a) throw new HttpsError("not-found", "Trip not found.");
    if (r.requesterId !== uid) {
      throw new HttpsError("permission-denied", "Only the User can pay.");
    }
    if (a.tripStatus !== "completed") {
      throw new HttpsError("failed-precondition", "The trip is not completed yet.", {code: "INVALID_STATE"});
    }
    if (a.requesterPaidAt) {
      throw new HttpsError("failed-precondition", "This trip is already paid.", {code: "ALREADY_PAID"});
    }
    const amountInr: number = a.amountInr ?? 0;
    if (amountInr <= 0) {
      throw new HttpsError("failed-precondition", "There is nothing to pay for this trip.", {code: "NO_AMOUNT"});
    }
    const keyId = RAZORPAY_KEY_ID.value();
    // Idempotent: if an order was already created for this still-unpaid trip,
    // return it rather than creating (and overwriting the stored id with) a new
    // one — otherwise a retry could orphan an order the User already paid.
    if (a.razorpayOrderId) {
      return {
        orderId: a.razorpayOrderId,
        keyId,
        amountPaise: amountInr * 100,
        amountInr,
        currency: "INR",
      };
    }
    const auth = Buffer.from(`${keyId}:${RAZORPAY_KEY_SECRET.value()}`).toString("base64");
    const resp = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {"Content-Type": "application/json", "Authorization": `Basic ${auth}`},
      body: JSON.stringify({
        amount: amountInr * 100, // paise
        currency: "INR",
        receipt: `${requestId}_${volunteerId}`.slice(0, 40),
        notes: {requestId, volunteerId},
      }),
    });
    if (!resp.ok) {
      const text = await resp.text().catch(() => "");
      logger.error("Razorpay order creation failed", {status: resp.status, text});
      throw new HttpsError("internal", "Could not start the payment. Please try again.");
    }
    const order = (await resp.json()) as {id: string};
    await assignRef.update({razorpayOrderId: order.id});
    return {
      orderId: order.id,
      keyId,
      amountPaise: amountInr * 100,
      amountInr,
      currency: "INR",
    };
  }
);

/**
 * Verifies a Razorpay payment signature (HMAC-SHA256 with the Key Secret) and,
 * if valid, marks the assignment paid (same transition as markPaid). Requester
 * only.
 */
export const verifyRazorpayPayment = onCall(
  {region: REGION, secrets: [RAZORPAY_KEY_SECRET]},
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
    const {requestId, volunteerId, razorpayOrderId, razorpayPaymentId, razorpaySignature} =
      req.data ?? {};
    if (!requestId || !volunteerId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      throw new HttpsError("invalid-argument", "Missing payment verification fields.");
    }
    const expected = crypto
      .createHmac("sha256", RAZORPAY_KEY_SECRET.value())
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest("hex");
    const sigOk =
      expected.length === String(razorpaySignature).length &&
      crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(String(razorpaySignature)));
    if (!sigOk) {
      throw new HttpsError("permission-denied", "The payment could not be verified.", {code: "BAD_SIGNATURE"});
    }
    const reqRef = db.collection("requests").doc(requestId);
    const assignRef = reqRef.collection("assignments").doc(volunteerId);
    await db.runTransaction(async (tx) => {
      const reqDoc = await tx.get(reqRef);
      if (reqDoc.data()?.requesterId !== uid) {
        throw new HttpsError("permission-denied", "Only the User can pay.");
      }
      const a = (await tx.get(assignRef)).data();
      if (!a) throw new HttpsError("not-found", "Assignment not found.");
      if (a.tripStatus !== "completed") {
        throw new HttpsError("failed-precondition", "The trip is not completed yet.", {code: "INVALID_STATE"});
      }
      if (a.razorpayOrderId !== razorpayOrderId) {
        throw new HttpsError("failed-precondition", "The payment order did not match this trip.", {code: "ORDER_MISMATCH"});
      }
      tx.update(assignRef, {
        razorpayOrderId,
        razorpayPaymentId,
        requesterPaidAt: a.requesterPaidAt ?? FieldValue.serverTimestamp(),
        paymentStatus: paymentStatusOf(true, a.travAcserReceivedAt),
      });
    });
    await pushToUser(volunteerId, {title: "Payment received", body: "The User paid you via Razorpay."}, {type: "payment_marked", requestId}).catch(() => {});
    return {ok: true, code: "PAID"};
  }
);

/** Mutual rating (User↔TravAcser) for a completed assignment. */
export const submitRating = onCall({region: REGION}, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please sign in.");
  const {requestId, volunteerId, stars, feedback} = req.data ?? {};
  if (!requestId || !volunteerId || typeof stars !== "number") {
    throw new HttpsError("invalid-argument", "requestId, volunteerId, stars required.");
  }
  if (!Number.isInteger(stars) || stars < 1 || stars > 5) {
    throw new HttpsError("invalid-argument", "Stars must be a whole number 1–5.");
  }
  if (feedback != null && (typeof feedback !== "string" || feedback.length > 1000)) {
    throw new HttpsError("invalid-argument", "Feedback must be text up to 1000 characters.");
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

/**
 * Admin logs a manually-booked (e.g. phone) trip into the `tripLogs` telemetry
 * collection. Admin-claim only. Two required fields (user + TravAcser details)
 * plus the trip date; an optional note.
 */
export const logManualTrip = onCall({region: REGION}, async (req) => {
  if (req.auth?.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin only.");
  }
  const {userDetails, travAcserDetails, tripDateMs, note} = req.data ?? {};
  if (!userDetails || !travAcserDetails || typeof tripDateMs !== "number") {
    throw new HttpsError("invalid-argument", "userDetails, travAcserDetails and tripDate are required.");
  }
  const ref = await db.collection("tripLogs").add({
    source: "manual",
    userDetails: String(userDetails),
    travAcserDetails: String(travAcserDetails),
    tripDate: Timestamp.fromMillis(tripDateMs),
    note: note ? String(note) : null,
    createdBy: req.auth!.uid,
    createdAt: FieldValue.serverTimestamp(),
  });
  return {ok: true, code: "LOGGED", id: ref.id};
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

/**
 * Periodically auto-expires unaccepted requests (item 2):
 *   • within 30 min of the scheduled start, still unaccepted → warn the User
 *     once ("we couldn't find a TravAcser; reschedule or it will be cancelled").
 *   • at/after the scheduled start, still unaccepted → auto-cancel + notify.
 */
export const expireStaleRequests = onSchedule(
  {region: SCHEDULER_REGION, schedule: "every 5 minutes"},
  async () => {
    const now = Date.now();
    const soon = Timestamp.fromMillis(now + 30 * 60000);
    const snap = await db
      .collection("requests")
      .where("status", "==", "broadcast")
      .where("scheduledStartAt", "<=", soon)
      .get();
    for (const doc of snap.docs) {
      let action: "cancelled" | "warned" | null = null;
      let requesterId: string | undefined;
      try {
        await db.runTransaction(async (tx) => {
          const cur = await tx.get(doc.ref);
          const r = cur.data();
          if (!r) return;
          requesterId = r.requesterId;
          // Re-check under the transaction: an accept may have landed between the
          // query above and now, which must NOT be overwritten with "cancelled".
          if (r.status !== "broadcast" || (r.acceptedCount ?? 0) > 0) return;
          const startMs = (r.scheduledStartAt as Timestamp | undefined)?.toMillis();
          if (startMs == null) return;
          if (now >= startMs) {
            tx.update(doc.ref, {
              status: "cancelled",
              cancelReason: "no_travacser",
              updatedAt: FieldValue.serverTimestamp(),
            });
            action = "cancelled";
          } else if (!r.noTravAcserNotifiedAt) {
            // Don't nag immediately after a short-notice trip is created (its
            // T-30 point may already be in the past): only warn once the request
            // has been live for a little while. Falls back to warning when
            // createdAt is missing.
            const createdMs = (r.createdAt as Timestamp | undefined)?.toMillis();
            const settled = createdMs == null || now >= createdMs + 10 * 60000;
            if (settled) {
              tx.update(doc.ref, {noTravAcserNotifiedAt: FieldValue.serverTimestamp()});
              action = "warned";
            }
          }
        });
        if (action && requesterId) {
          if (action === "cancelled") {
            await pushToUser(
              requesterId,
              {title: "Trip auto-cancelled", body: "We couldn't find a TravAcser in time, so your trip was cancelled. You can create a new request."},
              {type: "no_travacser_cancelled", requestId: doc.id}
            ).catch(() => {});
          } else {
            await pushToUser(
              requesterId,
              {title: "No TravAcser yet", body: "Sorry, we couldn't find a TravAcser. You can reschedule, or the trip will be auto-cancelled at its scheduled time."},
              {type: "no_travacser_warning", requestId: doc.id}
            ).catch(() => {});
          }
        }
      } catch (e) {
        logger.warn(`expireStaleRequests failed for ${doc.id}`, e);
      }
    }
  }
);

/**
 * Periodically auto-releases rescheduled assignments the TravAcser didn't
 * confirm before the deadline (item 3): cancels the slot, decrements the count
 * and reopens the request to the feed.
 */
export const expireRescheduleConfirmations = onSchedule(
  {region: SCHEDULER_REGION, schedule: "every 2 minutes"},
  async () => {
    const now = Timestamp.now();
    const snap = await db
      .collectionGroup("assignments")
      .where("rescheduleStatus", "==", "pending")
      .where("rescheduleDeadlineAt", "<=", now)
      .get();
    for (const doc of snap.docs) {
      const reqRef = doc.ref.parent.parent;
      if (!reqRef) continue;
      const volunteerId = doc.data().volunteerId as string | undefined;
      let requesterId: string | undefined;
      try {
        const didExpire = await db.runTransaction(async (tx) => {
          const reqDoc = await tx.get(reqRef);
          const r = reqDoc.data();
          if (!r) return false;
          requesterId = r.requesterId;
          const cur = (await tx.get(doc.ref)).data();
          if (!cur || cur.rescheduleStatus !== "pending") return false; // changed meanwhile
          tx.update(doc.ref, {
            tripStatus: "cancelled",
            rescheduleStatus: "expired",
            rescheduleDeadlineAt: FieldValue.delete(),
          });
          const accepted: number = r.acceptedCount ?? 0;
          tx.update(reqRef, {
            acceptedCount: Math.max(0, accepted - 1),
            status: r.status === "assigned" ? "broadcast" : r.status,
            updatedAt: FieldValue.serverTimestamp(),
          });
          return true;
        });
        // Only notify when the slot was actually released — if the TravAcser
        // confirmed just before the deadline, no expiry happened.
        if (!didExpire) continue;
        if (volunteerId) {
          await pushToUser(volunteerId, {title: "Reschedule expired", body: "You didn't confirm the new trip time in time, so the trip was released."}, {type: "reschedule_expired", requestId: reqRef.id}).catch(() => {});
        }
        if (requesterId) {
          await pushToUser(requesterId, {title: "A TravAcser dropped off", body: "A TravAcser didn't confirm the new time, so we've reopened your request."}, {type: "reschedule_expired", requestId: reqRef.id}).catch(() => {});
        }
      } catch (e) {
        logger.warn(`expireRescheduleConfirmations failed for ${doc.ref.path}`, e);
      }
    }
  }
);
