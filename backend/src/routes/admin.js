const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { requireRole } = require("../middleware/auth");
const { getFirebaseAuth } = require("../firebase");

const router = express.Router();

router.post(
  "/handshake/cleanup",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { days } = req.body || {};
    const supabase = getSupabase();
    const { data, error } = await supabase.rpc("cleanup_handshake_events", {
      p_days: days ?? 30
    });
    if (error) {
      throw new ApiError(error.message, 500, "HANDSHAKE_CLEANUP_FAILED");
    }
    return res.json({ deleted: data || 0 });
  })
);

router.post(
  "/roles/set",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { uid, role, roles } = req.body || {};
    if (!uid) {
      throw new ApiError("uid required", 400, "ROLE_INVALID_INPUT");
    }
    const firebaseAuth = getFirebaseAuth();
    if (!firebaseAuth) {
      throw new ApiError("Firebase admin not configured", 500, "AUTH_SERVER_MISCONFIGURED");
    }
    const claims = {};
    if (role) {
      claims.role = role;
    }
    if (Array.isArray(roles) && roles.length > 0) {
      claims.roles = roles;
    }
    if (!claims.role && !claims.roles) {
      throw new ApiError("role or roles required", 400, "ROLE_INVALID_INPUT");
    }
    await firebaseAuth.setCustomUserClaims(uid, claims);
    return res.json({ status: "ok", uid, claims });
  })
);

router.post(
  "/roles/clear",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { uid } = req.body || {};
    if (!uid) {
      throw new ApiError("uid required", 400, "ROLE_INVALID_INPUT");
    }
    const firebaseAuth = getFirebaseAuth();
    if (!firebaseAuth) {
      throw new ApiError("Firebase admin not configured", 500, "AUTH_SERVER_MISCONFIGURED");
    }
    await firebaseAuth.setCustomUserClaims(uid, {});
    return res.json({ status: "ok", uid });
  })
);

router.get(
  "/parcels",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("parcels")
      .select(
        "id,status,origin,destination,priority,fragile,assigned_courier_id,assigned_at,created_at,created_by"
      )
      .order("created_at", { ascending: false })
      .limit(200);
    if (error) {
      throw new ApiError(error.message, 500, "ADMIN_PARCELS_FETCH_FAILED");
    }
    return res.json({ parcels: data || [] });
  })
);

router.get(
  "/errors",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const {
      device_model,
      os_version,
      limit = 100,
      offset = 0,
      days = 7
    } = req.query || {};

    const supabase = getSupabase();
    const since = new Date();
    since.setDate(since.getDate() - Number(days));

    let query = supabase
      .from("error_logs")
      .select("*", { count: "exact" })
      .gte("occurred_at", since.toISOString())
      .order("occurred_at", { ascending: false });

    if (device_model) {
      query = query.eq("device_model", device_model);
    }
    if (os_version) {
      query = query.eq("os_version", os_version);
    }

    query = query.range(Number(offset), Number(offset) + Number(limit) - 1);

    const { data, error, count } = await query;

    if (error) {
      throw new ApiError(error.message, 500, "ERROR_LOG_FETCH_FAILED");
    }

    return res.json({
      total: count || 0,
      limit: Number(limit),
      offset: Number(offset),
      errors: data || []
    });
  })
);

router.get(
  "/errors/summary",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { days = 7 } = req.query || {};

    const supabase = getSupabase();
    const since = new Date();
    since.setDate(since.getDate() - Number(days));

    // Get total error count
    const { count: totalCount, error: countError } = await supabase
      .from("error_logs")
      .select("id", { count: "exact" })
      .gte("occurred_at", since.toISOString());

    if (countError) {
      throw new ApiError(countError.message, 500, "ERROR_SUMMARY_FAILED");
    }

    // Get errors by device
    const { data: deviceData, error: deviceError } = await supabase
      .from("error_logs")
      .select("device_model")
      .gte("occurred_at", since.toISOString());

    if (deviceError) {
      throw new ApiError(deviceError.message, 500, "DEVICE_SUMMARY_FAILED");
    }

    // Aggregate device counts
    const deviceCounts = {};
    (deviceData || []).forEach((error) => {
      const device = error.device_model || "unknown";
      deviceCounts[device] = (deviceCounts[device] || 0) + 1;
    });

    // Get errors by OS version
    const { data: osData, error: osError } = await supabase
      .from("error_logs")
      .select("os_version")
      .gte("occurred_at", since.toISOString());

    if (osError) {
      throw new ApiError(osError.message, 500, "OS_SUMMARY_FAILED");
    }

    // Aggregate OS counts
    const osCounts = {};
    (osData || []).forEach((error) => {
      const os = error.os_version || "unknown";
      osCounts[os] = (osCounts[os] || 0) + 1;
    });

    // Get top errors by stack trace frequency
    const { data: topErrors, error: topError } = await supabase
      .from("error_logs")
      .select("stack_trace")
      .gte("occurred_at", since.toISOString());

    if (topError) {
      throw new ApiError(topError.message, 500, "TOP_ERRORS_SUMMARY_FAILED");
    }

    const stackTraceCounts = {};
    (topErrors || []).forEach((error) => {
      const trace = error.stack_trace || "unknown";
      stackTraceCounts[trace] = (stackTraceCounts[trace] || 0) + 1;
    });

    const topStackTraces = Object.entries(stackTraceCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([stackTrace, count]) => ({ stackTrace, count }));

    return res.json({
      totalErrors: totalCount || 0,
      timeRange: { since: since.toISOString(), days: Number(days) },
      byDevice: deviceCounts,
      byOsVersion: osCounts,
      topErrors: topStackTraces
    });
  })
);

router.get(
  "/alerts/rules",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("alert_rules")
      .select("*")
      .order("created_at", { ascending: false });

    if (error) {
      throw new ApiError(error.message, 500, "ALERT_RULES_FETCH_FAILED");
    }

    return res.json({ rules: data || [] });
  })
);

router.post(
  "/alerts/rules",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { type, name, description, threshold, time_window_minutes, severity, notification_channels } =
      req.body || {};

    if (!type || !name) {
      throw new ApiError("type and name required", 400, "ALERT_INVALID_INPUT");
    }

    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("alert_rules")
      .insert({
        type,
        name,
        description,
        threshold,
        time_window_minutes,
        severity: severity || "warning",
        notification_channels: notification_channels || "slack"
      })
      .select();

    if (error) {
      throw new ApiError(error.message, 500, "ALERT_CREATE_FAILED");
    }

    return res.status(201).json({ rule: data?.[0] || {} });
  })
);

router.patch(
  "/alerts/rules/:id",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { enabled, threshold, severity, notification_channels } = req.body || {};

    const supabase = getSupabase();
    const updates = {};
    if (typeof enabled === "boolean") updates.enabled = enabled;
    if (typeof threshold === "number") updates.threshold = threshold;
    if (severity) updates.severity = severity;
    if (notification_channels) updates.notification_channels = notification_channels;
    updates.updated_at = new Date().toISOString();

    const { data, error } = await supabase
      .from("alert_rules")
      .update(updates)
      .eq("id", id)
      .select();

    if (error) {
      throw new ApiError(error.message, 500, "ALERT_UPDATE_FAILED");
    }

    return res.json({ rule: data?.[0] || {} });
  })
);

router.delete(
  "/alerts/rules/:id",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const supabase = getSupabase();

    const { error } = await supabase
      .from("alert_rules")
      .delete()
      .eq("id", id);

    if (error) {
      throw new ApiError(error.message, 500, "ALERT_DELETE_FAILED");
    }

    return res.json({ status: "ok", id });
  })
);

router.get(
  "/alerts/history",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { rule_id, limit = 100, offset = 0, days = 7 } = req.query || {};

    const supabase = getSupabase();
    const since = new Date();
    since.setDate(since.getDate() - Number(days));

    let query = supabase
      .from("alert_history")
      .select("*", { count: "exact" })
      .gte("triggered_at", since.toISOString())
      .order("triggered_at", { ascending: false });

    if (rule_id) {
      query = query.eq("rule_id", rule_id);
    }

    query = query.range(Number(offset), Number(offset) + Number(limit) - 1);

    const { data, error, count } = await query;

    if (error) {
      throw new ApiError(error.message, 500, "ALERT_HISTORY_FETCH_FAILED");
    }

    return res.json({
      total: count || 0,
      limit: Number(limit),
      offset: Number(offset),
      history: data || []
    });
  })
);

module.exports = router;
