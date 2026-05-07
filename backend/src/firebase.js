const admin = require("firebase-admin");
const config = require("./config");

let app;

function initializeFirebase() {
  if (app) {
    return app;
  }

  if (!config.firebaseProjectId || !config.firebaseClientEmail || !config.firebasePrivateKey) {
    return null;
  }

  app = admin.initializeApp({
    credential: admin.credential.cert({
      projectId: config.firebaseProjectId,
      clientEmail: config.firebaseClientEmail,
      privateKey: config.firebasePrivateKey.replace(/\\n/g, "\n")
    })
  });

  return app;
}

function getFirebaseAuth() {
  const initialized = initializeFirebase();
  if (!initialized) {
    return null;
  }
  return admin.auth();
}

function getFirebaseMessaging() {
  const initialized = initializeFirebase();
  if (!initialized) {
    return null;
  }
  return admin.messaging();
}

function getFirestore() {
  const initialized = initializeFirebase();
  if (!initialized) {
    return null;
  }
  return admin.firestore();
}

module.exports = {
  getFirebaseAuth,
  getFirebaseMessaging,
  getFirestore
};
