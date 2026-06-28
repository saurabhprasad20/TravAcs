import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";

initializeApp();
const db = getFirestore();

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
