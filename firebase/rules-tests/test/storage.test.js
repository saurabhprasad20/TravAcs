"use strict";

const { readFileSync } = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc, updateDoc, Timestamp } = require("firebase/firestore");
const {
  ref,
  uploadBytes,
  getBytes,
  deleteObject,
} = require("firebase/storage");

const PROJECT_ID = "demo-travacs";
const BUCKET = `${PROJECT_ID}.appspot.com`;
const RECEIPT_PATH = "payment-receipts/request-1/volunteer-1/receipt.jpg";

let testEnv;

async function seedAssignment() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await setDoc(
      doc(
        firestore,
        "requests/request-1/assignments/volunteer-1"
      ),
      {
        volunteerId: "volunteer-1",
        tripStatus: "completed",
      }
    );
    await setDoc(doc(firestore, "requests/request-1"), {
      paymentReviewStatus: "pending",
      paymentReviewEndsAt: Timestamp.fromMillis(Date.now() + 60_000),
    });
  });
}

function receipt(context, filePath = RECEIPT_PATH) {
  return ref(context.storage(BUCKET), filePath);
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(
        path.resolve(__dirname, "../../firestore.rules"),
        "utf8"
      ),
    },
    storage: {
      rules: readFileSync(
        path.resolve(__dirname, "../../storage.rules"),
        "utf8"
      ),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await seedAssignment();
});

describe("payment receipt storage", () => {
  it("allows the assignment owner to upload, read, and delete an unsubmitted receipt", async () => {
    const owner = testEnv.authenticatedContext("volunteer-1");
    const file = receipt(owner);

    await assertSucceeds(
      uploadBytes(file, new Uint8Array([1, 2, 3]), {
        contentType: "image/jpeg",
      })
    );
    await assertSucceeds(getBytes(file));
    await assertSucceeds(deleteObject(file));
  });

  it("denies another user access to the receipt", async () => {
    const owner = testEnv.authenticatedContext("volunteer-1");
    const other = testEnv.authenticatedContext("volunteer-2");
    await uploadBytes(receipt(owner), new Uint8Array([1]), {
      contentType: "image/jpeg",
    });

    await assertFails(getBytes(receipt(other)));
    await assertFails(
      uploadBytes(receipt(other), new Uint8Array([1]), {
        contentType: "image/jpeg",
      })
    );
    await deleteObject(receipt(owner));
  });

  it("allows an admin to read but not overwrite a receipt", async () => {
    const owner = testEnv.authenticatedContext("volunteer-1");
    const admin = testEnv.authenticatedContext("admin", { admin: true });
    await uploadBytes(receipt(owner), new Uint8Array([1]), {
      contentType: "image/jpeg",
    });

    await assertSucceeds(getBytes(receipt(admin)));
    await assertFails(
      uploadBytes(receipt(admin), new Uint8Array([2]), {
        contentType: "image/jpeg",
      })
    );
    await deleteObject(receipt(owner));
  });

  it("rejects unsupported content types and files of 5 MB or more", async () => {
    const owner = testEnv.authenticatedContext("volunteer-1");

    await assertFails(
      uploadBytes(receipt(owner, "payment-receipts/request-1/volunteer-1/a.txt"),
        new Uint8Array([1]), { contentType: "text/plain" })
    );
    await assertFails(
      uploadBytes(receipt(owner), new Uint8Array(5 * 1024 * 1024), {
        contentType: "image/jpeg",
      })
    );
  });

  it("prevents replacing or deleting a submitted receipt", async () => {
    const owner = testEnv.authenticatedContext("volunteer-1");
    const file = receipt(owner);
    await uploadBytes(file, new Uint8Array([1]), {
      contentType: "image/jpeg",
    });
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await updateDoc(
        doc(
          firestore,
          "requests/request-1/assignments/volunteer-1"
        ),
        { receiptStoragePath: RECEIPT_PATH }
      );
    });

    await assertFails(
      uploadBytes(file, new Uint8Array([2]), {
        contentType: "image/jpeg",
      })
    );
    await assertFails(deleteObject(file));
  });
});
