const express = require("express");
const multer = require("multer");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { requireUser, requireRole } = require("../middleware/auth");
const config = require("../config");

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 12 * 1024 * 1024 } });

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
      is_verified: false
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

router.get(
  "/search/recipient",
  requireRole("client"),
  asyncHandler(async (req, res) => {
    const q = (req.query?.q || "").toString().trim();
    if (q.length < 3) {
      throw new ApiError("Query must be at least 3 characters", 400, "SEARCH_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("users")
      .select("id,email,display_name,role")
      .ilike("email", `%${q}%`)
      .limit(8);
    if (error) {
      throw new ApiError(error.message, 500, "USER_SEARCH_FAILED");
    }
    const rows = (data || []).filter(
      (u) => u.id !== req.user?.uid && (u.role === "client" || u.role === "CLIENT")
    );
    return res.json({ users: rows });
  })
);

router.post(
  "/onboarding/document",
  requireUser,
  upload.single("file"),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      throw new ApiError("file required", 400, "ONBOARDING_FILE_REQUIRED");
    }
    const kind = (req.body?.kind || "").toString();
    if (!["id", "license", "vehicle"].includes(kind)) {
      throw new ApiError("kind must be id, license, or vehicle", 400, "ONBOARDING_INVALID_KIND");
    }
    if (!config.supabaseStorageBucket) {
      throw new ApiError(
        "Supabase storage bucket not configured",
        500,
        "ONBOARDING_STORAGE_MISCONFIGURED"
      );
    }
    const userId = req.user?.uid;
    const supabase = getSupabase();
    const timestamp = Date.now();
    const safeName = req.file.originalname.replace(/[^a-zA-Z0-9._-]/g, "_");
    const objectPath = `onboarding/${userId}/${kind}_${timestamp}_${safeName}`;
    const { error: uploadError } = await supabase.storage
      .from(config.supabaseStorageBucket)
      .upload(objectPath, req.file.buffer, {
        contentType: req.file.mimetype,
        upsert: false
      });
    if (uploadError) {
      throw new ApiError(uploadError.message, 500, "ONBOARDING_UPLOAD_FAILED");
    }
    const { data } = supabase.storage.from(config.supabaseStorageBucket).getPublicUrl(objectPath);
    const url = data.publicUrl;
    const column =
      kind === "id"
        ? "id_document_url"
        : kind === "license"
          ? "license_document_url"
          : "vehicle_document_url";
    const { error: updateError } = await supabase.from("users").upsert(
      {
        id: userId,
        email: req.user?.email,
        [column]: url,
        is_verified: false,
        updated_at: new Date().toISOString()
      },
      { onConflict: "id" }
    );
    if (updateError) {
      throw new ApiError(updateError.message, 500, "ONBOARDING_SAVE_FAILED");
    }
    return res.status(201).json({ url, kind });
  })
);

router.patch(
  "/onboarding/profile",
  requireUser,
  asyncHandler(async (req, res) => {
    const { displayName, phoneNumber } = req.body || {};
    const supabase = getSupabase();
    const updates = {
      id: req.user?.uid,
      email: req.user?.email,
      is_verified: false,
      updated_at: new Date().toISOString()
    };
    if (typeof displayName === "string" && displayName.trim()) {
      updates.display_name = displayName.trim();
    }
    if (typeof phoneNumber === "string" && phoneNumber.trim()) {
      updates.phone_number = phoneNumber.trim();
    }
    const { error } = await supabase.from("users").upsert(updates, { onConflict: "id" });
    if (error) {
      throw new ApiError(error.message, 500, "ONBOARDING_PROFILE_FAILED");
    }
    return res.json({ status: "ok" });
  })
);

// POST /users/courier/profile - Save courier profile (multi-step signup)
router.post(
  "/courier/profile",
  requireUser,
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const userId = req.user?.uid;
    const {
      full_name,
      id_number,
      id_image_url,
      license_number,
      license_image_url,
      vehicle_registration,
      vehicle_registration_images,
      vehicle_type,
      vehicle_make,
      vehicle_model,
      vehicle_year,
      vehicle_color,
      vehicle_capacity_kg
    } = req.body || {};

    if (!full_name || !id_number || !license_number) {
      throw new ApiError(
        "full_name, id_number, and license_number are required",
        400,
        "COURIER_PROFILE_INCOMPLETE"
      );
    }

    const supabase = getSupabase();

    // Upsert courier profile
    const { error } = await supabase.from("courier_profiles").upsert({
      id: userId,
      full_name,
      id_number,
      id_image_url,
      license_number,
      license_image_url,
      vehicle_registration,
      vehicle_registration_images: vehicle_registration_images || [],
      vehicle_type,
      vehicle_make,
      vehicle_model,
      vehicle_year,
      vehicle_color,
      vehicle_capacity_kg: vehicle_capacity_kg || 50,
      profile_complete: !!(
        full_name &&
        id_number &&
        id_image_url &&
        license_number &&
        license_image_url &&
        vehicle_registration
      ),
      updated_at: new Date().toISOString()
    });

    if (error) {
      throw new ApiError(error.message, 500, "COURIER_PROFILE_SAVE_FAILED");
    }

    // Update users table profile_step
    await supabase
      .from("users")
      .update({ profile_step: 4, profile_complete: true })
      .eq("id", userId);

    return res.json({ status: "ok", message: "Courier profile saved successfully" });
  })
);

// POST /users/client/profile - Save client profile (multi-step signup)
router.post(
  "/client/profile",
  requireUser,
  requireRole("client"),
  asyncHandler(async (req, res) => {
    const userId = req.user?.uid;
    const { full_name, username, id_number, id_image_url, phone_number } = req.body || {};

    if (!full_name || !username || !id_number) {
      throw new ApiError(
        "full_name, username, and id_number are required",
        400,
        "CLIENT_PROFILE_INCOMPLETE"
      );
    }

    const supabase = getSupabase();

    // Check if username is unique
    const { data: existingUsername } = await supabase
      .from("client_profiles")
      .select("id")
      .eq("username", username)
      .neq("id", userId)
      .maybeSingle();

    if (existingUsername) {
      throw new ApiError("Username already taken", 409, "USERNAME_TAKEN");
    }

    // Upsert client profile
    const { error } = await supabase.from("client_profiles").upsert({
      id: userId,
      full_name,
      username,
      id_number,
      id_image_url,
      phone_number,
      profile_complete: !!(full_name && username && id_number && id_image_url),
      updated_at: new Date().toISOString()
    });

    if (error) {
      throw new ApiError(error.message, 500, "CLIENT_PROFILE_SAVE_FAILED");
    }

    // Update users table profile_step
    await supabase
      .from("users")
      .update({ profile_step: 2, profile_complete: true })
      .eq("id", userId);

    return res.json({ status: "ok", message: "Client profile saved successfully" });
  })
);

// GET /users/courier/:id/profile - Get courier profile
router.get(
  "/courier/:id/profile",
  asyncHandler(async (req, res) => {
    const courierUserId = req.params.id;
    const supabase = getSupabase();

    const { data, error } = await supabase
      .from("courier_profiles")
      .select("*")
      .eq("id", courierUserId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "COURIER_PROFILE_LOOKUP_FAILED");
    }

    if (!data) {
      throw new ApiError("Courier profile not found", 404, "COURIER_PROFILE_NOT_FOUND");
    }

    return res.json(data);
  })
);

// GET /users/client/:id/profile - Get client profile
router.get(
  "/client/:id/profile",
  asyncHandler(async (req, res) => {
    const clientUserId = req.params.id;
    const supabase = getSupabase();

    const { data, error } = await supabase
      .from("client_profiles")
      .select("*")
      .eq("id", clientUserId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "CLIENT_PROFILE_LOOKUP_FAILED");
    }

    if (!data) {
      throw new ApiError("Client profile not found", 404, "CLIENT_PROFILE_NOT_FOUND");
    }

    return res.json(data);
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
