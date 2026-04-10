const { getFirebaseAuth } = require("../firebase");
const { getSupabase } = require("../supabase");
const config = require("../config");

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

  const firebaseAuth = getFirebaseAuth();
  if (!firebaseAuth) {
    return res.status(500).json({
      error: "Firebase admin not configured",
      code: "AUTH_SERVER_MISCONFIGURED"
    });
  }

  try {
    const decoded = await firebaseAuth.verifyIdToken(token);
    req.user = decoded;
    
    // Enhance user object with role from Supabase users table
    const supabase = getSupabase();
    if (supabase && decoded.uid) {
      const { data: userData, error: roleError } = await supabase
        .from("users")
        .select("role")
        .eq("id", decoded.uid)
        .maybeSingle();
      
      if (roleError) {
        console.error(`[Auth] Error loading user role for ${decoded.uid}:`, roleError.message);
      } else if (userData?.role) {
        req.user.role = userData.role;
        console.log(`[Auth] Loaded role for ${decoded.uid}: ${userData.role}`);
      } else {
        console.warn(`[Auth] No role found in DB for ${decoded.uid}. Data:`, userData);
      }
    } else {
      console.warn(`[Auth] Supabase not available or decoded.uid missing`);
    }
    
    return next();
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
