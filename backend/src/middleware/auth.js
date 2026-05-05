const { getFirebaseAuth } = require("../firebase");
const { getSupabase } = require("../supabase");
const config = require("../config");

async function attachRoleFromUsersTable(req, uid) {
  const supabase = getSupabase();
  if (!supabase || !uid) return;
  const { data: userData, error } = await supabase
    .from("users")
    .select("role")
    .eq("id", uid)
    .maybeSingle();

  if (error) {
    console.error(`[Auth] Error loading role for ${uid}:`, error.message);
    return;
  }
  if (userData?.role) {
    req.user.role = userData.role;
  }
}

async function verifySupabaseToken(token) {
  const supabase = getSupabase();
  if (!supabase) return null;
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) return null;
  return {
    uid: data.user.id,
    email: data.user.email,
    provider: "supabase",
    raw: data.user,
  };
}

async function authMiddleware(req, res, next) {
  if (!config.requireAuth) {
    return next();
  }

  const authHeader = req.headers.authorization || "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) {
    return res.status(401).json({
      error: "Missing bearer token",
      code: "AUTH_MISSING_TOKEN"
    });
  }

  try {
    const firebaseAuth = getFirebaseAuth();
    if (firebaseAuth) {
      try {
        const decoded = await firebaseAuth.verifyIdToken(token);
        req.user = decoded;
        await attachRoleFromUsersTable(req, decoded.uid);
        return next();
      } catch (_) {
        // Fall through to Supabase token verification.
      }
    }

    const supabaseUser = await verifySupabaseToken(token);
    if (supabaseUser) {
      req.user = {
        uid: supabaseUser.uid,
        email: supabaseUser.email,
        auth_provider: supabaseUser.provider,
        claims: {},
      };
      await attachRoleFromUsersTable(req, supabaseUser.uid);
      return next();
    }

    return res.status(401).json({
      error: "Invalid token",
      code: "AUTH_INVALID_TOKEN"
    });
  } catch (error) {
    return res.status(401).json({
      error: "Invalid token",
      code: "AUTH_INVALID_TOKEN"
    });
  }
}

function requireUser(req, res, next) {
  if (!req.user) {
    return res.status(401).json({
      error: "Authentication required",
      code: "AUTH_REQUIRED"
    });
  }
  return next();
}

function requireRole(role) {
  return (req, res, next) => {
    const userRole = req.user?.role || req.user?.roles || req.user?.claims?.role;
    if (!userRole) {
      return res.status(403).json({
        error: "Role required",
        code: "AUTH_ROLE_REQUIRED"
      });
    }
    const roles = Array.isArray(userRole) ? userRole : [userRole];
    if (!roles.includes(role)) {
      return res.status(403).json({
        error: "Insufficient role",
        code: "AUTH_ROLE_FORBIDDEN"
      });
    }
    return next();
  };
}

function requireAnyRole(roles) {
  return (req, res, next) => {
    const userRole = req.user?.role || req.user?.roles || req.user?.claims?.role;
    if (!userRole) {
      return res.status(403).json({
        error: "Role required",
        code: "AUTH_ROLE_REQUIRED"
      });
    }
    const assigned = Array.isArray(userRole) ? userRole : [userRole];
    const allowed = Array.isArray(roles) ? roles : [roles];
    const ok = assigned.some((r) => allowed.includes(r));
    if (!ok) {
      return res.status(403).json({
        error: "Insufficient role",
        code: "AUTH_ROLE_FORBIDDEN"
      });
    }
    return next();
  };
}

module.exports = {
  authMiddleware,
  requireUser,
  requireRole,
  requireAnyRole
};
