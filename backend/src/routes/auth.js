const express = require("express");
const https = require("https");
const config = require("../config");
const { getFirebaseAuth } = require("../firebase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");

const router = express.Router();
const rateBuckets = new Map();
const AUTH_WINDOW_MS = 10 * 60 * 1000;
const AUTH_LIMIT = 20;
const REFRESH_LIMIT = 40;

function rateLimit(req, limit) {
  const ip = req.ip || req.connection?.remoteAddress || "unknown";
  const key = `${ip}:${req.path}`;
  const now = Date.now();
  const bucket = rateBuckets.get(key) || [];
  const recent = bucket.filter((timestamp) => now - timestamp < AUTH_WINDOW_MS);
  if (recent.length >= limit) {
    throw new ApiError("Too many auth attempts. Try later.", 429, "AUTH_RATE_LIMIT");
  }
  recent.push(now);
  rateBuckets.set(key, recent);
}

function callFirebaseAuth(endpoint, payload) {
  return new Promise((resolve, reject) => {
    if (!config.firebaseWebApiKey) {
      reject(new ApiError("Firebase web API key not configured", 500, "AUTH_SERVER_MISCONFIGURED"));
      return;
    }

    const body = JSON.stringify({
      ...payload,
      returnSecureToken: true
    });

    const req = https.request(
      {
        method: "POST",
        hostname: "identitytoolkit.googleapis.com",
        path: `/v1/${endpoint}?key=${config.firebaseWebApiKey}`,
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body)
        }
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => {
          data += chunk;
        });
        res.on("end", () => {
          if (res.statusCode && res.statusCode >= 400) {
            reject(new ApiError(data, 400, "AUTH_PROVIDER_ERROR"));
            return;
          }
          try {
            resolve(JSON.parse(data));
          } catch (error) {
            reject(error);
          }
        });
      }
    );

    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function callFirebaseTokenRefresh(refreshToken) {
  return new Promise((resolve, reject) => {
    if (!config.firebaseWebApiKey) {
      reject(new ApiError("Firebase web API key not configured", 500, "AUTH_SERVER_MISCONFIGURED"));
      return;
    }

    const body = `grant_type=refresh_token&refresh_token=${encodeURIComponent(
      refreshToken
    )}`;

    const req = https.request(
      {
        method: "POST",
        hostname: "securetoken.googleapis.com",
        path: `/v1/token?key=${config.firebaseWebApiKey}`,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Content-Length": Buffer.byteLength(body)
        }
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => {
          data += chunk;
        });
        res.on("end", () => {
          if (res.statusCode && res.statusCode >= 400) {
            reject(new ApiError(data, 400, "AUTH_PROVIDER_ERROR"));
            return;
          }
          try {
            resolve(JSON.parse(data));
          } catch (error) {
            reject(error);
          }
        });
      }
    );

    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

router.post(
  "/signup",
  asyncHandler(async (req, res) => {
    console.log(`[AUTH] 👤 Signup attempt for: ${req.body?.email}`);
    console.log(`[AUTH] 📡 Request from: ${req.ip} User-Agent: ${req.headers['user-agent']}`);

    rateLimit(req, AUTH_LIMIT);
    const { email, password, displayName } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({
        error: "email and password required",
        code: "AUTH_INVALID_INPUT"
      });
    }

    console.log(`[AUTH] 🔄 Calling Firebase signup for: ${email}`);
    const response = await callFirebaseAuth("accounts:signUp", {
      email,
      password,
      displayName
    });

    console.log(`[AUTH] ✅ Signup successful for: ${email} (UID: ${response.localId})`);
    return res.status(201).json({
      idToken: response.idToken,
      refreshToken: response.refreshToken,
      expiresIn: response.expiresIn,
      localId: response.localId
    });
  })
);

router.post(
  "/login",
  asyncHandler(async (req, res) => {
    console.log(`[AUTH] 🔐 Login attempt for: ${req.body?.email}`);
    console.log(`[AUTH] 📡 Request from: ${req.ip} User-Agent: ${req.headers['user-agent']}`);

    rateLimit(req, AUTH_LIMIT);
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({
        error: "email and password required",
        code: "AUTH_INVALID_INPUT"
      });
    }

    console.log(`[AUTH] 🔄 Calling Firebase for: ${email}`);
    const response = await callFirebaseAuth("accounts:signInWithPassword", {
      email,
      password
    });

    console.log(`[AUTH] ✅ Login successful for: ${email} (UID: ${response.localId})`);
    return res.json({
      idToken: response.idToken,
      refreshToken: response.refreshToken,
      expiresIn: response.expiresIn,
      localId: response.localId
    });
  })
);

router.post(
  "/refresh",
  asyncHandler(async (req, res) => {
    rateLimit(req, REFRESH_LIMIT);
    const { refreshToken } = req.body || {};
    if (!refreshToken) {
      return res.status(400).json({
        error: "refreshToken required",
        code: "AUTH_INVALID_INPUT"
      });
    }

    const response = await callFirebaseTokenRefresh(refreshToken);
    return res.json({
      idToken: response.id_token,
      refreshToken: response.refresh_token,
      expiresIn: response.expires_in,
      localId: response.user_id
    });
  })
);

// Role-specific signup endpoints (for multi-step signup workflows)
router.post(
  "/signup/courier",
  asyncHandler(async (req, res) => {
    console.log(`[AUTH] 👨‍💼 Courier signup attempt for: ${req.body?.email}`);
    
    rateLimit(req, AUTH_LIMIT);
    const { email, password, displayName } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({
        error: "email and password required",
        code: "AUTH_INVALID_INPUT"
      });
    }

    console.log(`[AUTH] 🔄 Calling Firebase signup for courier: ${email}`);
    const response = await callFirebaseAuth("accounts:signUp", {
      email,
      password,
      displayName
    });

    console.log(`[AUTH] ✅ Courier signup successful for: ${email} (UID: ${response.localId})`);
    
    // Auto-setup courier role
    const { getSupabase } = require("../supabase");
    const supabase = getSupabase();
    await supabase
      .from("users")
      .upsert({
        id: response.localId,
        email,
        role: "courier",
        display_name: displayName,
        auth_method: "firebase",
        profile_step: 1,
        verified_at: null
      });

    return res.status(201).json({
      idToken: response.idToken,
      refreshToken: response.refreshToken,
      expiresIn: response.expiresIn,
      localId: response.localId,
      role: "courier"
    });
  })
);

router.post(
  "/signup/client",
  asyncHandler(async (req, res) => {
    console.log(`[AUTH] 👤 Client signup attempt for: ${req.body?.email}`);
    
    rateLimit(req, AUTH_LIMIT);
    const { email, password, displayName } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({
        error: "email and password required",
        code: "AUTH_INVALID_INPUT"
      });
    }

    console.log(`[AUTH] 🔄 Calling Firebase signup for client: ${email}`);
    const response = await callFirebaseAuth("accounts:signUp", {
      email,
      password,
      displayName
    });

    console.log(`[AUTH] ✅ Client signup successful for: ${email} (UID: ${response.localId})`);
    
    // Auto-setup client role
    const { getSupabase } = require("../supabase");
    const supabase = getSupabase();
    await supabase
      .from("users")
      .upsert({
        id: response.localId,
        email,
        role: "client",
        display_name: displayName,
        auth_method: "firebase",
        profile_step: 1,
        verified_at: null
      });

    return res.status(201).json({
      idToken: response.idToken,
      refreshToken: response.refreshToken,
      expiresIn: response.expiresIn,
      localId: response.localId,
      role: "client"
    });
  })
);

// Role-specific login endpoints
router.post(
  "/login/courier",
  asyncHandler(async (req, res) => {
    console.log(`[AUTH] 🔐 Courier login attempt for: ${req.body?.email}`);
    
    rateLimit(req, AUTH_LIMIT);
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({
        error: "email and password required",
        code: "AUTH_INVALID_INPUT"
      });
    }

    const response = await callFirebaseAuth("accounts:signInWithPassword", {
      email,
      password
    });

    console.log(`[AUTH] ✅ Courier login successful for: ${email} (UID: ${response.localId})`);
    
    // Verify role is courier
    const { getSupabase } = require("../supabase");
    const supabase = getSupabase();
    const { data: user } = await supabase
      .from("users")
      .select("role")
      .eq("id", response.localId)
      .single();

    if (user?.role !== "courier") {
      throw new ApiError("Invalid role for this endpoint", 403, "AUTH_ROLE_MISMATCH");
    }

    return res.json({
      idToken: response.idToken,
      refreshToken: response.refreshToken,
      expiresIn: response.expiresIn,
      localId: response.localId,
      role: "courier"
    });
  })
);

router.post(
  "/login/client",
  asyncHandler(async (req, res) => {
    console.log(`[AUTH] 🔐 Client login attempt for: ${req.body?.email}`);
    
    rateLimit(req, AUTH_LIMIT);
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({
        error: "email and password required",
        code: "AUTH_INVALID_INPUT"
      });
    }

    const response = await callFirebaseAuth("accounts:signInWithPassword", {
      email,
      password
    });

    console.log(`[AUTH] ✅ Client login successful for: ${email} (UID: ${response.localId})`);
    
    // Verify role is client
    const { getSupabase } = require("../supabase");
    const supabase = getSupabase();
    const { data: user } = await supabase
      .from("users")
      .select("role")
      .eq("id", response.localId)
      .single();

    if (user?.role !== "client") {
      throw new ApiError("Invalid role for this endpoint", 403, "AUTH_ROLE_MISMATCH");
    }

    return res.json({
      idToken: response.idToken,
      refreshToken: response.refreshToken,
      expiresIn: response.expiresIn,
      localId: response.localId,
      role: "client"
    });
  })
);

async function validateRoleByEmail(email, requiredRole) {
  const { getSupabase } = require("../supabase");
  const supabase = getSupabase();
  const { data: user, error } = await supabase
    .from("users")
    .select("role")
    .eq("email", email)
    .maybeSingle();
  if (error) {
    throw new ApiError(error.message, 500, "AUTH_ROLE_LOOKUP_FAILED");
  }
  if (!user || user.role !== requiredRole) {
    throw new ApiError("Invalid role for this endpoint", 403, "AUTH_ROLE_MISMATCH");
  }
}

router.post(
  "/forgot-password",
  asyncHandler(async (req, res) => {
    rateLimit(req, AUTH_LIMIT);
    const { email } = req.body || {};
    if (!email) {
      return res.status(400).json({
        error: "email required",
        code: "AUTH_INVALID_INPUT"
      });
    }
    await callFirebaseAuth("accounts:sendOobCode", {
      requestType: "PASSWORD_RESET",
      email
    });
    return res.json({ status: "ok", message: "Password reset email sent" });
  })
);

router.post(
  "/forgot-password/courier",
  asyncHandler(async (req, res) => {
    rateLimit(req, AUTH_LIMIT);
    const { email } = req.body || {};
    if (!email) {
      return res.status(400).json({
        error: "email required",
        code: "AUTH_INVALID_INPUT"
      });
    }
    await validateRoleByEmail(email, "courier");
    await callFirebaseAuth("accounts:sendOobCode", {
      requestType: "PASSWORD_RESET",
      email
    });
    return res.json({ status: "ok", message: "Password reset email sent" });
  })
);

router.post(
  "/forgot-password/client",
  asyncHandler(async (req, res) => {
    rateLimit(req, AUTH_LIMIT);
    const { email } = req.body || {};
    if (!email) {
      return res.status(400).json({
        error: "email required",
        code: "AUTH_INVALID_INPUT"
      });
    }
    await validateRoleByEmail(email, "client");
    await callFirebaseAuth("accounts:sendOobCode", {
      requestType: "PASSWORD_RESET",
      email
    });
    return res.json({ status: "ok", message: "Password reset email sent" });
  })
);

router.post(
  "/verify",
  asyncHandler(async (req, res) => {
    rateLimit(req, REFRESH_LIMIT);
    const { idToken } = req.body || {};
    if (!idToken) {
      return res.status(400).json({
        error: "idToken required",
        code: "AUTH_INVALID_INPUT"
      });
    }

    const firebaseAuth = getFirebaseAuth();
    if (!firebaseAuth) {
      return res.status(500).json({
        error: "Firebase admin not configured",
        code: "AUTH_SERVER_MISCONFIGURED"
      });
    }

    try {
      const decoded = await firebaseAuth.verifyIdToken(idToken);
      return res.json({ uid: decoded.uid, claims: decoded });
    } catch (_error) {
      throw new ApiError("Invalid token", 401, "AUTH_INVALID_TOKEN");
    }
  })
);

module.exports = router;
