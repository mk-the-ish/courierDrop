const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { requireUser } = require("../middleware/auth");

const router = express.Router();

// GET /users/me - Get current user profile
router.get(
  "/me",
  requireUser,
  asyncHandler(async (req, res) => {
    const userId = req.user?.uid;
    if (!userId) {
      throw new ApiError("User ID not found in token", 400, "USER_ID_MISSING");
    }

    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("users")
      .select("*")
      .eq("id", userId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "USER_LOOKUP_FAILED");
    }

    if (!data) {
      // User record doesn't exist yet - return profile from token
      return res.json({
        id: userId,
        email: req.user?.email,
        displayName: req.user?.name,
        role: null,
        verified_at: null,
        created_at: null
      });
    }

    return res.json(data);
  })
);

// POST /users/setup-role - Set user role (client or courier)
// This is called after signup to assign the user's role
router.post(
  "/setup-role",
  requireUser,
  asyncHandler(async (req, res) => {
    const userId = req.user?.uid;
    if (!userId) {
      throw new ApiError("User ID not found in token", 400, "USER_ID_MISSING");
    }

    const { role, displayName } = req.body || {};

    if (!role || !["client", "courier"].includes(role)) {
      throw new ApiError(
        "role must be 'client' or 'courier'",
        400,
        "USER_INVALID_ROLE"
      );
    }

    const supabase = getSupabase();

    // Check if user already has a role
    const { data: existing, error: lookupError } = await supabase
      .from("users")
      .select("role")
      .eq("id", userId)
      .maybeSingle();

    if (lookupError) {
      throw new ApiError(lookupError.message, 500, "USER_LOOKUP_FAILED");
    }

    if (existing && existing.role) {
      throw new ApiError(
        "User role already set. Contact support to change role.",
        409,
        "USER_ROLE_ALREADY_SET"
      );
    }

    const payload = {
      id: userId,
      role,
      email: req.user?.email,
      display_name: displayName || req.user?.name,
      verified_at: new Date().toISOString()
    };

    // Use upsert to handle both new users and existing ones
    const { error: upsertError } = await supabase
      .from("users")
      .upsert(payload, { onConflict: "id" })
      .select("id");

    if (upsertError) {
      throw new ApiError(upsertError.message, 500, "USER_SETUP_FAILED");
    }

    return res.status(201).json({
      id: userId,
      role,
      message: `User role set to ${role}`
    });
  })
);

// GET /users/:id - Get user profile by ID (admin only)
router.get(
  "/:id",
  asyncHandler(async (req, res) => {
    const userId = req.params.id;
    if (!userId) {
      throw new ApiError("User ID required", 400, "USER_ID_REQUIRED");
    }

    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("users")
      .select("id,role,display_name,email,verified_at,created_at")
      .eq("id", userId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "USER_LOOKUP_FAILED");
    }

    if (!data) {
      throw new ApiError("User not found", 404, "USER_NOT_FOUND");
    }

    return res.json(data);
  })
);

module.exports = router;
