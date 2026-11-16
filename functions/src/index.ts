import * as crypto from "crypto";
import { KeyManagementServiceClient } from "@google-cloud/kms";
import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";

admin.initializeApp();
const db = admin.firestore();
const kmsClient = new KeyManagementServiceClient();

// Configuration parameters
const kmsKeyNameParam = defineString("KMS_KEY_NAME", {
  default: "projects/mymail-app/locations/global/keyRings/mymail-ring/cryptoKeys/recovery-key",
  description: "Full resource path to the Cloud KMS key for recovery wrap",
});

/**
 * Masks an email for display: user@example.com -> u***@example.com
 */
function maskEmail(email: string): string {
  const parts = email.split("@");
  if (parts.length !== 2) return email;
  const name = parts[0];
  const domain = parts[1];
  const maskedName = name.length > 2 ? `${name[0]}***${name[name.length - 1]}` : `${name[0]}***`;
  return `${maskedName}@${domain}`;
}

/**
 * 1. setRecoveryWrap
 * Receives the 256-bit Vault Key (VK) over TLS from authenticated client,
 * encrypts it with Cloud KMS, and stores the recovery wrap in Firestore
 * under users/{uid}/private/recovery.
 */
export const setRecoveryWrap = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated with Google.");
  }

  const uid = request.auth.uid;
  const vaultKey = request.data?.vaultKey;

  if (!vaultKey || typeof vaultKey !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid 'vaultKey' base64 string.");
  }

  const keyName = kmsKeyNameParam.value();

  try {
    // Encrypt Vault Key with Google Cloud KMS
    const [encryptResponse] = await kmsClient.encrypt({
      name: keyName,
      plaintext: Buffer.from(vaultKey, "base64"),
    });

    if (!encryptResponse.ciphertext) {
      throw new Error("KMS encryption returned empty ciphertext.");
    }

    const recoveryWrap = Buffer.from(encryptResponse.ciphertext).toString("base64");

    // Store encrypted recovery wrap in protected subcollection
    await db.collection("users").doc(uid).collection("private").doc("recovery").set(
      {
        recoveryWrap,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Mark email recovery enabled in user document
    await db.collection("users").doc(uid).set(
      {
        emailRecoveryEnabled: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { success: true };
  } catch (error: any) {
    console.error("Error setting recovery wrap:", error);
    throw new HttpsError("internal", error.message || "Failed to encrypt and store recovery wrap.");
  }
});

/**
 * 2. requestRecovery
 * Verifies the user's Firebase Auth ID token, generates a single-use 6-digit code,
 * computes SHA-256 hash, stores hash with a 15-minute expiry, and dispatches the code
 * to the registered Google email address only.
 */
export const requestRecovery = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated with Google.");
  }

  const uid = request.auth.uid;
  const userEmail = request.auth.token.email;

  if (!userEmail) {
    throw new HttpsError("failed-precondition", "No registered Google email found on the authentication token.");
  }

  // Check if recovery is enabled
  const userDoc = await db.collection("users").doc(uid).get();
  const userData = userDoc.data();
  if (userData && userData.emailRecoveryEnabled === false) {
    throw new HttpsError("failed-precondition", "Email recovery is disabled for this account.");
  }

  // Ensure recovery wrap exists
  const recoveryDoc = await db.collection("users").doc(uid).collection("private").doc("recovery").get();
  if (!recoveryDoc.exists || !recoveryDoc.data()?.recoveryWrap) {
    throw new HttpsError("not-found", "No recovery key found for this vault.");
  }

  // Generate 6-digit cryptographically secure code
  const code = crypto.randomInt(100000, 1000000).toString();

  // Compute SHA-256 hash of the code (plaintext code is never persisted)
  const codeHash = crypto.createHash("sha256").update(code).digest("hex");
  const expiresAt = Date.now() + 15 * 60 * 1000; // 15 minutes validity

  // Save hash, expiry, reset attempts and used status in Firestore
  await db.collection("users").doc(uid).collection("private").doc("recovery").set(
    {
      codeHash,
      expiresAt,
      attempts: 0,
      isUsed: false,
      lastRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // Send email via "Trigger Email from Firestore" extension
  // Plain, clear email format as requested:
  // "Your MyMail recovery code is 123456. It expires in 15 minutes."
  await db.collection("mail").add({
    to: [userEmail],
    message: {
      subject: "Your MyMail recovery code",
      text: `Your MyMail recovery code is ${code}. It expires in 15 minutes.`,
      html: `<p style="font-family: sans-serif; font-size: 16px; color: #111;">Your MyMail recovery code is <strong>${code}</strong>. It expires in 15 minutes.</p>`,
    },
  });

  return {
    success: true,
    emailMasked: maskEmail(userEmail),
    expiresInMinutes: 15,
  };
});

/**
 * 3. verifyRecovery
 * Validates the single-use 6-digit recovery code.
 * Limits to 5 attempts. If valid and not expired, decrypts the VK via Cloud KMS
 * and returns it over TLS to the client session.
 */
export const verifyRecovery = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated with Google.");
  }

  const uid = request.auth.uid;
  const inputCode = request.data?.code;

  if (!inputCode || typeof inputCode !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid 'code' string.");
  }

  const cleanCode = inputCode.trim();
  if (cleanCode.length !== 6 || !/^\d{6}$/.test(cleanCode)) {
    throw new HttpsError("invalid-argument", "Recovery code must be exactly 6 digits.");
  }

  const recoveryRef = db.collection("users").doc(uid).collection("private").doc("recovery");
  const recoveryDoc = await recoveryRef.get();

  if (!recoveryDoc.exists) {
    throw new HttpsError("not-found", "No recovery session found.");
  }

  const data = recoveryDoc.data()!;
  const recoveryWrap = data.recoveryWrap;
  const storedHash = data.codeHash;
  const expiresAt = data.expiresAt as number;
  const attempts = (data.attempts as number) || 0;
  const isUsed = (data.isUsed as boolean) || false;

  if (!recoveryWrap) {
    throw new HttpsError("failed-precondition", "No recovery wrap available to decrypt.");
  }

  // Check if code was already used
  if (isUsed) {
    throw new HttpsError("failed-precondition", "Recovery code has already been used. Please request a new code.");
  }

  // Check if code has expired
  if (Date.now() > expiresAt) {
    throw new HttpsError("deadline-exceeded", "Recovery code has expired (15 minute limit). Please request a new code.");
  }

  // Check max attempts
  if (attempts >= 5) {
    throw new HttpsError("resource-exhausted", "Maximum verification attempts (5) reached. Please request a new code.");
  }

  // Validate SHA-256 hash
  const inputHash = crypto.createHash("sha256").update(cleanCode).digest("hex");

  if (inputHash !== storedHash) {
    const updatedAttempts = attempts + 1;
    await recoveryRef.update({ attempts: updatedAttempts });
    const remaining = Math.max(0, 5 - updatedAttempts);
    throw new HttpsError("invalid-argument", `Invalid recovery code. ${remaining} attempt(s) remaining.`);
  }

  // Mark code as used immediately (single-use)
  await recoveryRef.update({
    isUsed: true,
    recoveredAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const keyName = kmsKeyNameParam.value();

  try {
    // Decrypt Vault Key with Google Cloud KMS
    const [decryptResponse] = await kmsClient.decrypt({
      name: keyName,
      ciphertext: Buffer.from(recoveryWrap, "base64"),
    });

    if (!decryptResponse.plaintext) {
      throw new Error("KMS decryption produced empty plaintext.");
    }

    const vaultKey = Buffer.from(decryptResponse.plaintext).toString("base64");

    return {
      success: true,
      vaultKey,
    };
  } catch (error: any) {
    console.error("Error decrypting with KMS:", error);
    throw new HttpsError("internal", "Failed to decrypt Vault Key with KMS.");
  }
});

/**
 * 4. disableRecovery
 * Allows the user to disable email recovery and delete their KMS recovery wrap.
 */
export const disableRecovery = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated with Google.");
  }

  const uid = request.auth.uid;

  await db.collection("users").doc(uid).set(
    {
      emailRecoveryEnabled: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await db.collection("users").doc(uid).collection("private").doc("recovery").delete();

  return { success: true };
});
