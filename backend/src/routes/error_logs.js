const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");

const router = express.Router();

const conflictAttempts = new Map();
const CONFLICT_WINDOW_MS = 10 * 60 * 1000;
const CONFLICT_MAX = 5;

function checkConflictRateLimit(key) {
  const now = Date.now();
  const bucket = conflictAttempts.get(key) || [];
  const recent = bucket.filter((timestamp) => now - timestamp < CONFLICT_WINDOW_MS);
  if (recent.length >= CONFLICT_MAX) {
    return false;
  }
  recent.push(now);
  conflictAttempts.set(key, recent);
  return true;
}

router.post(
  "/error",
  asyncHandler(async (req, res) => {
    const {
      userId,
      deviceModel,
      osVersion,
      stackTrace,
      context,
      timestamp,
      clientId
    } = req.body || {};

    if (!stackTrace) {
      throw new ApiError("stackTrace required", 400, "ERROR_LOG_INVALID_INPUT");
    }

    const supabase = getSupabase();
    const resolvedUserId = userId || req.user?.uid || null;

    if (clientId) {
      const { data: existing, error: lookupError } = await supabase
        .from("error_logs")
        .select("user_id")
        .eq("id", clientId)
        .maybeSingle();

      if (lookupError) {
        throw new ApiError(lookupError.message, 500, "ERROR_LOG_LOOKUP_FAILED");
      }

      if (existing && existing.user_id && existing.user_id !== resolvedUserId) {
        const rateKey = `errorlog:${req.user?.uid || "anon"}`;
        if (!checkConflictRateLimit(rateKey)) {
          throw new ApiError(
            "Too many conflict attempts. Try again later.",
            429,
            "ERROR_LOG_CONFLICT_RATE_LIMIT"
          );
        }
        throw new ApiError(
          "clientId already used by another user",
          409,
          "ERROR_LOG_CONFLICT"
        );
      }
    }

    const payload = {
      ...(clientId ? { id: clientId } : {}),
      user_id: resolvedUserId,
      device_model: deviceModel || null,
      os_version: osVersion || null,
      stack_trace: stackTrace,
      context: context || null,
      occurred_at: timestamp
        ? new Date(timestamp).toISOString()
        : new Date().toISOString(),
      request_id: req.requestId || null
    };

    const { error } = await supabase
      .from("error_logs")
      .upsert(payload, { onConflict: "id" });

    if (error) {
      throw new ApiError(error.message, 500, "ERROR_LOG_INSERT_FAILED");
    }

    return res.status(201).json({ status: "ok" });
  })
);

module.exports = router;
