import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";

admin.initializeApp();
const db = admin.firestore();

/**
 * 100% Free Server Secret for Encrypting Vault Recovery Wraps.
 * Eliminates Google Cloud KMS to guarantee $0.00/month cost forever.
 */
const recoverySecretParam = defineString("RECOVERY_SECRET", {
  default: "mymail-vault-free-server-recovery-key-32b!",
  description: "Internal server secret for encrypting recovery wraps (100% Free, no Cloud KMS cost)",
});

function getServerKey(): Buffer {
  const secret = recoverySecretParam.value() || "mymail-vault-free-server-recovery-key-32b!";
  return crypto.createHash("sha256").update(secret).digest();
}

/**
 * Server-side AES-256-GCM encryption
 */
function serverEncrypt(plaintextBase64: string): string {
  const key = getServerKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const plaintext = Buffer.from(plaintextBase64, "base64");
  const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tag = cipher.getAuthTag();
  // Packed format: iv (12 bytes) + tag (16 bytes) + ciphertext
  return Buffer.concat([iv, tag, encrypted]).toString("base64");
}

/**
 * Server-side AES-256-GCM decryption
 */
function serverDecrypt(envelopeBase64: string): string {
  const key = getServerKey();
  const raw = Buffer.from(envelopeBase64, "base64");
  if (raw.length < 28) {
    throw new Error("Invalid recovery envelope length.");
  }
  const iv = raw.subarray(0, 12);
  const tag = raw.subarray(12, 28);
  const ciphertext = raw.subarray(28);

  const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  return decrypted.toString("base64");
}

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
 * encrypts it server-side using AES-256-GCM (100% Free), and stores the
 * recovery wrap in Firestore under users/{uid}/private/recovery.
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

  try {
    // Encrypt Vault Key server-side (100% Free, zero cloud cost)
    const recoveryWrap = serverEncrypt(vaultKey);

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
 * Limits to 5 attempts. If valid and not expired, decrypts the VK server-side
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

  try {
    // Decrypt Vault Key server-side (100% Free, zero cloud cost)
    const vaultKey = serverDecrypt(recoveryWrap);

    return {
      success: true,
      vaultKey,
    };
  } catch (error: any) {
    console.error("Error decrypting recovery wrap:", error);
    throw new HttpsError("internal", "Failed to decrypt Vault Key.");
  }
});

/**
 * 4. disableRecovery
 * Allows the user to disable email recovery and delete their server recovery wrap.
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
