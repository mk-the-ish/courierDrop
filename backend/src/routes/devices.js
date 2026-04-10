const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");

const router = express.Router();

router.post(
  "/register",
  asyncHandler(async (req, res) => {
    const { token, platform } = req.body || {};
    if (!token) {
      throw new ApiError("token required", 400, "DEVICE_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { error } = await supabase.from("device_tokens").upsert(
      {
        user_id: req.user?.uid || "",
        token,
        platform: platform || null,
        last_seen_at: new Date().toISOString()
      },
      { onConflict: "token" }
    );
    if (error) {
      throw new ApiError(error.message, 500, "DEVICE_REGISTER_FAILED");
    }
    return res.json({ status: "ok" });
  })
);

module.exports = router;
