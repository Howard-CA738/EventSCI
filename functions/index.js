const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp }      = require("firebase-admin/app");
const { getFirestore }       = require("firebase-admin/firestore");
const CryptoJS               = require("crypto-js");
const crypto                 = require("crypto");

initializeApp();

const AES_KEY = "EvSc2024SecureKeyUPEUDNI32CharsX";
const AES_IV  = "InitVector161616";

function encryptAES(text) {
  const cipher = crypto.createCipheriv(
    "aes-256-cbc",
    Buffer.from(AES_KEY, "utf8"),
    Buffer.from(AES_IV, "utf8")
  );
  let encrypted = cipher.update(text, "utf8", "base64");
  encrypted += cipher.final("base64");
  return encrypted;
}

function decryptAES(encryptedBase64) {
  const decipher = crypto.createDecipheriv(
    "aes-256-cbc",
    Buffer.from(AES_KEY, "utf8"),
    Buffer.from(AES_IV, "utf8")
  );
  let decrypted = decipher.update(encryptedBase64, "base64", "utf8");
  decrypted += decipher.final("utf8");
  return decrypted;
}

// ─── ESTUDIANTES ─────────────────────────────────────────────────────────────

exports.encryptStudentDni = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");

  const { carreraPath, studentId, dni, adminId } = request.data;

  if (!carreraPath || !studentId || !dni) {
    throw new HttpsError("invalid-argument", "Faltan parámetros");
  }

  await verificarAdmin(adminId);

  const db        = getFirestore();
  const encrypted = encryptAES(dni);

  await db
    .collection("users")
    .doc(carreraPath)
    .collection("students")
    .doc(studentId)
    .update({ dniEncrypted: encrypted });

  return { success: true };
});

exports.decryptStudentDni = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");

  const { carreraPath, studentId, adminId } = request.data;

  if (!carreraPath || !studentId) {
    throw new HttpsError("invalid-argument", "Faltan parámetros");
  }

  const adminDoc = await verificarAdmin(adminId);
  const db       = getFirestore();

  const studentSnap = await db
    .collection("users")
    .doc(carreraPath)
    .collection("students")
    .doc(studentId)
    .get();

  if (!studentSnap.exists) {
    throw new HttpsError("not-found", "Estudiante no encontrado");
  }

  const encrypted = studentSnap.data().dniEncrypted;

  if (!encrypted) return { dni: "" };

  try {
    const dni = decryptAES(encrypted);

    await db.collection("audit_logs").add({
      accion:     "ver_dni_estudiante",
      carreraPath,
      studentId,
      adminId:    adminDoc.id,
      timestamp:  new Date(),
    });

    return { dni };
  } catch (e) {
    console.error("Error descifrando DNI:", e.message);
    return { dni: "" };
  }
});

// ─── JURADOS ──────────────────────────────────────────────────────────────────

exports.encryptJuradoPassword = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");

  const { juradoId, password, adminId } = request.data;

  if (!juradoId || !password) {
    throw new HttpsError("invalid-argument", "Faltan parámetros");
  }

  const db        = getFirestore();
  const encrypted = encryptAES(password);

  await db.collection("users").doc(juradoId).update({
    passwordEncrypted: encrypted,
  });

  return { success: true };
});

exports.decryptJuradoPassword = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");

  const { juradoId, adminId } = request.data;

  if (!juradoId) {
    throw new HttpsError("invalid-argument", "Falta juradoId");
  }

  const db         = getFirestore();
  const juradoSnap = await db.collection("users").doc(juradoId).get();

  if (!juradoSnap.exists) {
    throw new HttpsError("not-found", "Jurado no encontrado");
  }

  const encrypted = juradoSnap.data().passwordEncrypted;

  if (!encrypted) return { password: "" };

  try {
    const password = decryptAES(encrypted);
    return { password };
  } catch (e) {
    console.error("Error descifrando password jurado:", e.message);
    return { password: "" };
  }
});