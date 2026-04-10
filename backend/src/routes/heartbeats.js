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
  "/",
  asyncHandler(async (req, res) => {
    const { jobName, expectedFrequencySec, status } = req.body || {};

    if (!jobName || !expectedFrequencySec) {
      throw new ApiError("Missing required fields", 400, "HEARTBEAT_INVALID_INPUT");
    }

    const supabase = getSupabase();
    const { data: existing, error: lookupError } = await supabase
      .from("job_heartbeats")
      .select("created_by")
      .eq("job_name", jobName)
      .maybeSingle();

    if (lookupError) {
      throw new ApiError(lookupError.message, 500, "HEARTBEAT_LOOKUP_FAILED");
    }

    if (existing && existing.created_by && existing.created_by !== req.user?.uid) {
      const rateKey = `heartbeat:${req.user?.uid || "anon"}`;
      if (!checkConflictRateLimit(rateKey)) {
        throw new ApiError(
          "Too many conflict attempts. Try again later.",
          429,
          "HEARTBEAT_CONFLICT_RATE_LIMIT"
        );
      }
      throw new ApiError(
        "job_name already used by another user",
        409,
        "HEARTBEAT_CONFLICT"
      );
    }

    const payload = {
      job_name: jobName,
      expected_frequency_sec: expectedFrequencySec,
      status: status || "ACTIVE",
      last_heartbeat_at: new Date().toISOString(),
      last_status_change_at: new Date().toISOString(),
      created_by: req.user?.uid || null,
      request_id: req.requestId || null,
      updated_at: new Date().toISOString()
    };

    const { error } = await supabase.from("job_heartbeats").upsert(payload);

    if (error) {
      throw new ApiError(error.message, 500, "HEARTBEAT_UPSERT_FAILED");
    }

    return res.json({ status: "ok" });
  })
);

module.exports = router;
