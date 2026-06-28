import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
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
  const secretRef = reqRef.collection("secrets").doc(uid);
  const otp = String(Math.floor(100000 + Math.random() * 900000));

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
      landmark: r.landmark ?? null,
      numTravellers: r.numTravellers ?? 1,
      amountInrEstimate: perTravAcserInr,
      tripStatus: "assigned",
    });
    tx.set(secretRef, {otp, createdAt: FieldValue.serverTimestamp()});
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
