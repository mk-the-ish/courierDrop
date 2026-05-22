require("dotenv").config();

const config = {
  port: Number(process.env.PORT || 8080),
  supabaseUrl: process.env.SUPABASE_URL || "",
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || "",
  supabaseStorageBucket: process.env.SUPABASE_STORAGE_BUCKET || "",
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || "",
  firebaseClientEmail: process.env.FIREBASE_CLIENT_EMAIL || "",
  firebasePrivateKey: process.env.FIREBASE_PRIVATE_KEY || "",
  firebaseWebApiKey: process.env.FIREBASE_WEB_API_KEY || "",
  googleMapsServerApiKey: process.env.GOOGLE_MAPS_SERVER_API_KEY || process.env.MAPS_API_KEY || "",
  requireAuth: (process.env.REQUIRE_AUTH || "true").toLowerCase() === "true",
  twilioAccountSid: process.env.TWILIO_ACCOUNT_SID || "",
  twilioAuthToken: process.env.TWILIO_AUTH_TOKEN || "",
  twilioFromNumber: process.env.TWILIO_FROM_NUMBER || ""
};

module.exports = config;
