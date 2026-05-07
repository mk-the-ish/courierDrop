const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { requireRole } = require("../middleware/auth");
const { getFirebaseAuth } = require("../firebase");
const { getScheduler } = require("../services/scheduler");
const { matchPendingParcels } = require("../services/matching");

const router = express.Router();

router.get(
  "/health/heartbeats",
  requireRole("admin"),
  asyncHandler(async (_req, res) => {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("job_heartbeats")
      .select("job_name,last_heartbeat_at,expected_frequency_sec,status")
      .order("job_name", { ascending: true });
    if (error) {
      throw new ApiError(error.message, 500, "HEARTBEAT_FETCH_FAILED");
    }
    return res.json({ heartbeats: data || [] });
  })
);

router.get(
  "/jobs/active",
  requireRole("admin"),
  asyncHandler(async (_req, res) => {
    const scheduler = getScheduler();
    return res.json({
      schedulerRunning: scheduler.isRunning(),
      jobs: scheduler.getAllJobsStatus()
    });
  })
);

router.post(
  "/jobs/trigger-match-corridors",
  requireRole("admin"),
  asyncHandler(async (_req, res) => {
    await matchPendingParcels();
    return res.json({ status: "ok", triggered: "match_corridors" });
  })
);

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
  "/vehicles/pending",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    req.query.status = "unverified";
    const supabase = getSupabase();
    const { limit = 50, offset = 0 } = req.query || {};
    const { data, error, count } = await supabase
      .from("vehicles")
      .select(
        `
        id,courier_id,vehicle_type,make,model,year,color,license_plate,max_capacity_kg,current_utilization_kg,is_active,verification_status,created_at,updated_at,
        users:courier_id(id,email,display_name,phone_number,role)
        `,
        { count: "exact" }
      )
      .eq("verification_status", "unverified")
      .order("created_at", { ascending: false })
      .range(Number(offset), Number(offset) + Number(limit) - 1);
    if (error) {
      throw new ApiError(error.message, 500, "VEHICLE_FETCH_FAILED");
    }
    return res.json({ total: count || 0, vehicles: data || [] });
  })
);

router.post(
  "/vehicles/:id/verify",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { approved, verified } = req.body || {};
    const isApproved = typeof approved === "boolean" ? approved : Boolean(verified);
    const supabase = getSupabase();
    const status = isApproved ? "verified" : "rejected";
    const { data, error } = await supabase
      .from("vehicles")
      .update({
        verification_status: status,
        updated_at: new Date().toISOString()
      })
      .eq("id", id)
      .select()
      .single();
    if (error) {
      throw new ApiError(error.message, 500, "VEHICLE_VERIFY_FAILED");
    }
    return res.json({ status: "ok", vehicle: data });
  })
);

router.get(
  "/settings",
  requireRole("admin"),
  asyncHandler(async (_req, res) => {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("system_settings")
      .select("key,value,updated_at,updated_by")
      .order("key", { ascending: true });
    if (error) {
      throw new ApiError(error.message, 500, "SETTINGS_FETCH_FAILED");
    }
    return res.json({ settings: data || [] });
  })
);

router.post(
  "/settings",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const updates = req.body?.settings;
    if (!Array.isArray(updates)) {
      throw new ApiError("settings array required", 400, "SETTINGS_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const payload = updates.map((item) => ({
      key: item.key,
      value: item.value,
      updated_by: req.user?.uid || null,
      updated_at: new Date().toISOString()
    }));
    const { error } = await supabase
      .from("system_settings")
      .upsert(payload, { onConflict: "key" });
    if (error) {
      throw new ApiError(error.message, 500, "SETTINGS_UPDATE_FAILED");
    }
    return res.json({ status: "ok" });
  })
);

router.get(
  "/tracking/observability",
  requireRole("admin"),
  asyncHandler(async (_req, res) => {
    const supabase = getSupabase();
    const now = new Date();
    const tenMinutesAgo = new Date(now.getTime() - 10 * 60 * 1000).toISOString();
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();

    const [inTransitRes, staleRes, alertsRes, trackingRes] = await Promise.all([
      supabase.from("parcels").select("id", { count: "exact", head: true }).eq("status", "IN_TRANSIT"),
      supabase
        .from("parcels")
        .select("id", { count: "exact", head: true })
        .eq("status", "IN_TRANSIT")
        .or(`tracking_last_update.is.null,tracking_last_update.lt.${tenMinutesAgo}`),
      supabase
        .from("route_deviation_events")
        .select("id,deviation_type,created_at")
        .gte("created_at", twentyFourHoursAgo),
      supabase
        .from("courier_tracking_logs")
        .select("id", { count: "exact", head: true })
        .gte("created_at", twentyFourHoursAgo)
    ]);

    const aggregateAlerts = {};
    for (const alert of alertsRes.data || []) {
      const key = alert.deviation_type || "UNKNOWN";
      aggregateAlerts[key] = (aggregateAlerts[key] || 0) + 1;
    }

    const scheduler = getScheduler();
    const trackingJob = scheduler.getJobStatus("validate_tracking");
    const cleanupJob = scheduler.getJobStatus("cleanup_tracking_data");

    return res.json({
      inTransitCount: inTransitRes.count || 0,
      stalledTrackingCount: staleRes.count || 0,
      trackingLogsLast24h: trackingRes.count || 0,
      deviationEventsLast24h: aggregateAlerts,
      scheduler: {
        validateTracking: trackingJob,
        cleanupTrackingData: cleanupJob
      }
    });
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

// Vehicle Verification Endpoints
router.get(
  "/vehicles",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { status, limit = 50, offset = 0 } = req.query || {};
    const supabase = getSupabase();

    let query = supabase
      .from("vehicles")
      .select(
        `
        id,
        courier_id,
        vehicle_type,
        make,
        model,
        year,
        color,
        license_plate,
        max_capacity_kg,
        current_utilization_kg,
        is_active,
        verification_status,
        created_at,
        updated_at,
        users:courier_id(
          id,
          email,
          display_name,
          phone_number,
          role
        )
        `,
        { count: "exact" }
      )
      .order("created_at", { ascending: false });

    if (status) {
      query = query.eq("verification_status", status);
    }

    query = query.range(Number(offset), Number(offset) + Number(limit) - 1);

    const { data, error, count } = await query;

    if (error) {
      throw new ApiError(error.message, 500, "VEHICLE_FETCH_FAILED");
    }

    return res.json({
      total: count || 0,
      limit: Number(limit),
      offset: Number(offset),
      vehicles: data || []
    });
  })
);

router.get(
  "/vehicles/:id",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const supabase = getSupabase();

    const { data, error } = await supabase
      .from("vehicles")
      .select(
        `
        id,
        courier_id,
        vehicle_type,
        make,
        model,
        year,
        color,
        license_plate,
        max_capacity_kg,
        current_utilization_kg,
        is_active,
        verification_status,
        created_at,
        updated_at,
        users:courier_id(
          id,
          email,
          display_name,
          phone_number,
          role
        )
        `
      )
      .eq("id", id)
      .single();

    if (error) {
      throw new ApiError(error.message, 404, "VEHICLE_NOT_FOUND");
    }

    return res.json(data);
  })
);

router.patch(
  "/vehicles/:id/verify",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { verified, notes } = req.body || {};

    if (verified === undefined) {
      throw new ApiError("verified (boolean) required", 400, "INVALID_INPUT");
    }

    const supabase = getSupabase();
    const status = verified ? "verified" : "rejected";

    const { data, error } = await supabase
      .from("vehicles")
      .update({
        verification_status: status,
        updated_at: new Date().toISOString()
      })
      .eq("id", id)
      .select()
      .single();

    if (error) {
      throw new ApiError(error.message, 500, "VEHICLE_VERIFY_FAILED");
    }

    return res.json({
      status: "ok",
      vehicle: data,
      message: `Vehicle ${verified ? "verified" : "rejected"} successfully`
    });
  })
);

router.delete(
  "/vehicles/:id",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const supabase = getSupabase();

    const { error } = await supabase
      .from("vehicles")
      .delete()
      .eq("id", id);

    if (error) {
      throw new ApiError(error.message, 500, "VEHICLE_DELETE_FAILED");
    }

    return res.json({ status: "ok", id });
  })
);

// Couriers endpoint - list all couriers with their status
router.get(
  "/couriers",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const supabase = getSupabase();
    const { limit = 100, offset = 0 } = req.query || {};

    const { data, error, count } = await supabase
      .from("users")
      .select("id,email,display_name,phone_number,role,created_at,updated_at", { count: "exact" })
      .eq("role", "COURIER")
      .order("created_at", { ascending: false })
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    if (error) {
      throw new ApiError(error.message, 500, "COURIER_FETCH_FAILED");
    }

    return res.json({
      total: count || 0,
      limit: Number(limit),
      offset: Number(offset),
      couriers: data || []
    });
  })
);

module.exports = router;
