/**
 * Courier Tracking Routes
 * Handles real-time location updates with dual-mode spatial validation
 * - Corridor Mode: ST_DWithin corridor geometry
 * - Vector Mode: Distance heuristic for off-corridor movement
 */

const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { requireRole } = require("../middleware/auth");
const { broadcastTrackingUpdate } = require("../ws");
const { enqueueNotification } = require("../services/notification_service");
const { NOTIFICATION_EVENT_TYPES } = require("../services/notification_events");
const { calculateVectorProgress } = require("../services/tracking_vector");
const { connectivityAudit } = require("../services/connectivity_audit_service");
const {
  analyzeParcelHeuristics,
  computeInstantDiagnostics
} = require("../services/heuristic_tracking");
const { estimateParcelEta } = require("../services/eta_model");

const router = express.Router();

const CORRIDOR_TOLERANCE_M = 500;
const BATCH_SYNC_MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours
const ETA_NOTIFY_MIN_INTERVAL_MS = 5 * 60 * 1000;
const ETA_NOTIFY_DELTA_MINUTES = 4;

/**
 * POST /tracking/update
 * High-frequency endpoint for courier location pulses
 * Validates corridor allegiance and calculates progress
 */
router.post(
  "/update",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const { parcelId, lat, lng, accuracy, viaBatchSync, deviceInfo, networkInfo } = req.body || {};
    const courierId = req.user?.uid;

    console.log(`[Tracking.update] START: courierId=${courierId}, parcelId=${parcelId}, lat=${lat}, lng=${lng}, accuracy=${accuracy}`);

    if (typeof lat !== "number" || typeof lng !== "number" || !parcelId) {
      console.warn(`[Tracking.update] INVALID_INPUT: lat type=${typeof lat}, lng type=${typeof lng}, parcelId=${parcelId}`);
      throw new ApiError(
        "parcelId, lat, lng required",
        400,
        "TRACKING_INVALID_INPUT"
      );
    }

    const supabase = getSupabase();

    // Get parcel with corridor info
    const { data: parcel, error: parcelError } = await supabase
      .from("parcels")
      .select(
        "id,status,destination_point,assigned_courier_id,assigned_at,pickup_verified_at,created_by"
      )
      .eq("id", parcelId)
      .maybeSingle();

    if (parcelError) {
      console.error(`[Tracking.update] PARCEL_FETCH_ERROR: parcelId=${parcelId}, error=${parcelError.message}`);
      throw new ApiError(parcelError.message, 500, "TRACKING_PARCEL_FAILED");
    }
    if (!parcel) {
      console.warn(`[Tracking.update] PARCEL_NOT_FOUND: parcelId=${parcelId}`);
      throw new ApiError("Parcel not found", 404, "TRACKING_PARCEL_NOT_FOUND");
    }
    console.log(`[Tracking.update] Parcel found: status=${parcel.status}, assigned_to=${parcel.assigned_courier_id}, pickup_verified=${!!parcel.pickup_verified_at}`);

    // Verify courier is assigned
    if (parcel.assigned_courier_id !== courierId) {
      console.warn(`[Tracking.update] NOT_ASSIGNED: parcel assigned to=${parcel.assigned_courier_id}, requester=${courierId}`);
      throw new ApiError(
        "Not assigned to this parcel",
        403,
        "TRACKING_NOT_ASSIGNED"
      );
    }

    // Only track if pickup is verified and delivery not yet complete
    if (!parcel.pickup_verified_at || parcel.status === "COMPLETED") {
      console.log(`[Tracking.update] IGNORED: parcelId=${parcelId}, reason=pickup_verified:${!!parcel.pickup_verified_at}, status=${parcel.status}`);
      return res.json({ status: "ignored", reason: "parcel_not_in_transit" });
    }
    console.log(`[Tracking.update] PROCESSING: parcelId=${parcelId}`);

    const courierLocation = `POINT(${lng} ${lat})`;

    // Get assigned corridor for this courier
    const { data: assignedCorridor, error: corridorError } = await supabase
      .from("parcel_assignment_queue")
      .select("corridors!inner(id,corridor_line)")
      .eq("parcel_id", parcelId)
      .eq("status", "ASSIGNED")
      .maybeSingle();

    if (corridorError) {
      console.error(
        `[Tracking] Error fetching corridor for parcel ${parcelId}:`,
        corridorError
      );
    }

    const corridorId = assignedCorridor?.corridors?.id;
    const corridorLine = assignedCorridor?.corridors?.corridor_line;

    // Determine if on corridor (Corridor Mode)
    let isOnCorridor = false;
    let progressIndex = null;

    if (corridorLine) {
      // Use PostGIS to check if within tolerance of corridor
      const { data: corridorCheck, error: corridorCheckError } = await supabase.rpc(
        "st_dwithin",
        {
          geom1: courierLocation,
          geom2: corridorLine,
          distance: CORRIDOR_TOLERANCE_M
        }
      );

      if (!corridorCheckError && corridorCheck) {
        isOnCorridor = true;

        // Calculate progress on corridor
        const { data: progressData, error: progressError } = await supabase.rpc(
          "calculate_courier_progress",
          {
            p_corridor_id: corridorId,
            p_courier_location: courierLocation
          }
        );

        if (!progressError && progressData) {
          progressIndex = progressData[0]?.progress_index;
        }
      }
    }

    // If not on corridor, use Vector Mode (heuristic)
    let isMovingPositively = null;
    const destinationPoint = parcel.destination_point;

    if (!isOnCorridor && destinationPoint) {
      // Calculate distance to destination
      const { data: distanceCheck, error: distanceError } = await supabase.rpc(
        "detect_positive_movement",
        {
          p_parcel_id: parcelId,
          p_current_distance_m: `st_distance('${courierLocation}'::geography, '${destinationPoint}'::geography)`
        }
      );

      if (!distanceError && distanceCheck) {
        isMovingPositively = distanceCheck[0]?.is_moving_positive;
      }
    }

    // Get current distance to destination for logging
    const { data: distanceResult } = await supabase.rpc("st_distance", {
      geom1: courierLocation,
      geom2: destinationPoint
    });

    const distanceToDestination =
      typeof distanceResult === "number" ? distanceResult : null;

    const { data: lastPulse } = await supabase
      .from("courier_tracking_logs")
      .select("created_at,current_distance_m,raw_location")
      .eq("parcel_id", parcelId)
      .eq("courier_id", courierId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    const nowIso = new Date().toISOString();
    await connectivityAudit({
      courierId,
      parcelId,
      lat,
      lng,
      lastPulseAt: lastPulse?.created_at,
      currentPulseAt: nowIso,
      networkInfo
    });

    const vectorDelta = calculateVectorProgress(
      distanceToDestination,
      lastPulse?.current_distance_m
    );

    const lastWkt = (lastPulse?.raw_location || "").toString();
    const lastMatch = lastWkt.match(/POINT\(([-\d.]+)\s+([-\d.]+)\)/i);
    const lastPulsePoint = lastMatch
      ? { lat: Number(lastMatch[2]), lng: Number(lastMatch[1]) }
      : null;
    const diagnostics = computeInstantDiagnostics({
      nowIso,
      lat,
      lng,
      isOnCorridor,
      currentDistanceM: distanceToDestination,
      lastPulse: {
        created_at: lastPulse?.created_at,
        current_distance_m: lastPulse?.current_distance_m,
        lat: lastPulsePoint?.lat,
        lng: lastPulsePoint?.lng
      }
    });

    // Log the tracking event
    const { error: logError } = await supabase
      .from("courier_tracking_logs")
      .insert({
        parcel_id: parcelId,
        courier_id: courierId,
        raw_location: courierLocation,
        corridor_id: corridorId,
        is_on_corridor: isOnCorridor,
        progress_index: progressIndex,
        current_distance_m: distanceToDestination,
        movement_direction: isMovingPositively ? "TOWARD_DESTINATION" : null,
        via_batch_sync: Boolean(viaBatchSync),
        device_info: deviceInfo && typeof deviceInfo === "object" ? deviceInfo : {},
        network_info: networkInfo && typeof networkInfo === "object" ? networkInfo : {},
        vector_progress_delta: vectorDelta,
        speed_kmh: diagnostics.speedKmh,
        heuristic_flags: {
          ...diagnostics.flags,
          movement_confidence: diagnostics.movementConfidence,
          checkpoint_confidence: diagnostics.checkpointConfidence,
          route_adherence_score: diagnostics.routeAdherenceScore
        },
        created_at: nowIso
      });

    if (logError) {
      console.error(
        `[Tracking] Error logging location for parcel ${parcelId}:`,
        logError
      );
    }

    // Calculate progress percentage for client
    const progressPercentage = isOnCorridor
      ? Math.min(100, Math.max(0, (progressIndex || 0) * 100))
      : distanceToDestination && parcel.destination_point
        ? Math.max(
            0,
            100 - (distanceToDestination / (200 * 1000)) * 100 // Rough heuristic
          )
        : null;

    // Determine integrity status
    let integrityStatus = "NOMINAL";
    if (isOnCorridor) {
      integrityStatus = "ON_CORRIDOR";
    } else if (isMovingPositively) {
      integrityStatus = "MOVING_POSITIVELY";
    } else {
      integrityStatus = "OFF_CORRIDOR_STATIONARY";
    }

    // Update Firestore public document (privacy-preserving)
    // Note: This would integrate with Firebase Admin SDK
    // For now, we store the summary in a dedicated table
    const { error: updateError } = await supabase
      .from("parcels")
      .update({
        tracking_progress_percent: progressPercentage,
        tracking_integrity_status: integrityStatus,
        tracking_last_update: new Date().toISOString()
      })
      .eq("id", parcelId);

    if (updateError) {
      console.error(`[Tracking.update] PARCELS_UPDATE_ERROR: parcelId=${parcelId}, progress=${progressPercentage}%, status=${integrityStatus}, error=${updateError.message}`);
    } else {
      console.log(`[Tracking.update] PARCELS_UPDATED: parcelId=${parcelId}, progress=${progressPercentage}%, status=${integrityStatus}, distance=${distanceToDestination}m, onCorridor=${isOnCorridor}`);
    }
    broadcastTrackingUpdate(parcelId, {
      parcelId,
      progress_percent: progressPercentage,
      integrity_status: integrityStatus,
      tracking_last_update: new Date().toISOString(),
      on_corridor: isOnCorridor
    });

    // Sender ETA notifications (throttled + significant-delta gated).
    try {
      if (parcel.created_by) {
        const eta = await estimateParcelEta(parcelId);
        if (eta?.etaMinutes) {
          const { data: lastEtaNotification } = await supabase
            .from("notifications")
            .select("created_at,payload")
            .eq("type", NOTIFICATION_EVENT_TYPES.SENDER_ETA_UPDATE)
            .eq("entity_type", "parcel")
            .eq("entity_id", String(parcelId))
            .order("created_at", { ascending: false })
            .limit(1)
            .maybeSingle();

          const nowMs = Date.now();
          const lastCreatedMs = lastEtaNotification?.created_at
            ? new Date(lastEtaNotification.created_at).getTime()
            : 0;
          const withinInterval =
            lastCreatedMs > 0 && nowMs - lastCreatedMs < ETA_NOTIFY_MIN_INTERVAL_MS;
          const lastEtaMinutes = Number(lastEtaNotification?.payload?.etaMinutes);
          const hasLargeDelta =
            Number.isFinite(lastEtaMinutes) &&
            Math.abs(lastEtaMinutes - eta.etaMinutes) >= ETA_NOTIFY_DELTA_MINUTES;

          if (!withinInterval || hasLargeDelta) {
            await enqueueNotification({
              type: NOTIFICATION_EVENT_TYPES.SENDER_ETA_UPDATE,
              title: "Delivery ETA updated",
              body: `Courier ETA is now about ${eta.etaMinutes} min.`,
              recipients: [parcel.created_by],
              entityType: "parcel",
              entityId: parcelId,
              payload: {
                parcelId,
                etaMinutes: eta.etaMinutes,
                confidence: eta.confidence || "LOW",
                confidenceScore: eta.confidenceScore ?? null,
                distanceMeters: eta.distanceMeters ?? null,
                sourceBreakdown: eta.sourceBreakdown || []
              }
            });
          }
        }
      }
    } catch (etaNotifyError) {
      console.warn(
        `[Tracking.update] ETA notify skipped: parcelId=${parcelId}, error=${etaNotifyError.message}`
      );
    }

    console.log(`[Tracking.update] SUCCESS: parcelId=${parcelId}, response sent`);
    return res.json({
      status: "ok",
      progress_percent: progressPercentage,
      on_corridor: isOnCorridor,
      integrity_status: integrityStatus,
      distance_m: distanceToDestination,
      diagnostics: {
        movementConfidence: diagnostics.movementConfidence,
        checkpointConfidence: diagnostics.checkpointConfidence,
        routeAdherenceScore: diagnostics.routeAdherenceScore,
        speedKmh: diagnostics.speedKmh,
        flags: diagnostics.flags
      }
    });
  })
);

/**
 * GET /tracking/alerts/me
 * Courier-facing route deviation alerts only (no raw coordinates)
 */
router.get(
  "/alerts/me",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const supabase = getSupabase();
    const since = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();

    const { data, error } = await supabase
      .from("route_deviation_events")
      .select("id,parcel_id,deviation_type,duration_seconds,created_at")
      .eq("courier_id", courierId)
      .gte("created_at", since)
      .order("created_at", { ascending: false })
      .limit(25);

    if (error) {
      throw new ApiError(error.message, 500, "TRACKING_ALERTS_FETCH_FAILED");
    }

    return res.json({ alerts: data || [] });
  })
);

/**
 * POST /tracking/batch-sync
 * Endpoint for offline-first batch uploads from courier app
 * Accepts array of tracking updates to process
 */
router.post(
  "/batch-sync",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const { updates } = req.body || {};
    const courierId = req.user?.uid;

    console.log(`[Tracking.batch-sync] START: courierId=${courierId}, batchSize=${Array.isArray(updates) ? updates.length : 0}`);

    if (!Array.isArray(updates) || updates.length === 0) {
      console.warn(`[Tracking.batch-sync] INVALID_BATCH: updates type=${typeof updates}, isArray=${Array.isArray(updates)}`);
      throw new ApiError("updates array required", 400, "TRACKING_INVALID_BATCH");
    }

    const supabase = getSupabase();
    const results = [];
    let successCount = 0;

    for (const update of updates) {
      const { parcelId, lat, lng, accuracy, timestamp } = update;
      console.log(`[Tracking.batch-sync] Processing: parcelId=${parcelId}, lat=${lat}, lng=${lng}, age=${Date.now() - new Date(timestamp).getTime()}ms`);
      try {
        // Use same validation as single update endpoint
        if (typeof lat !== "number" || typeof lng !== "number" || !parcelId) {
          console.warn(`[Tracking.batch-sync] SKIPPED invalid_coordinates: parcelId=${parcelId}, lat type=${typeof lat}, lng type=${typeof lng}`);
          results.push({
            parcelId,
            status: "skipped",
            reason: "invalid_coordinates"
          });
          continue;
        }

        // Check if update is too old (>24 hours)
        const updateAge = Date.now() - new Date(timestamp).getTime();
        if (updateAge > BATCH_SYNC_MAX_AGE_MS) {
          await supabase.from("connectivity_audit").insert({
            courier_id: courierId,
            parcel_id: parcelId || null,
            lat,
            lng,
            source: "batch_sync_failure",
            reason: "too_old",
            age_ms: updateAge,
            created_at: new Date().toISOString()
          });
          console.warn(`[Tracking.batch-sync] SKIPPED too_old: parcelId=${parcelId}, age=${updateAge}ms`);
          results.push({
            parcelId,
            status: "skipped",
            reason: "too_old"
          });
          continue;
        }

        // Verify parcel assignment
        const { data: parcel, error: parcelError } = await supabase
          .from("parcels")
          .select("id,status,assigned_courier_id")
          .eq("id", parcelId)
          .maybeSingle();

        if (parcelError || !parcel || parcel.assigned_courier_id !== courierId) {
          await supabase.from("connectivity_audit").insert({
            courier_id: courierId,
            parcel_id: parcelId,
            lat,
            lng,
            source: "batch_sync_failure",
            reason: "unauthorized",
            age_ms: updateAge,
            created_at: new Date().toISOString()
          });
          console.warn(`[Tracking.batch-sync] SKIPPED unauthorized: parcelId=${parcelId}`);
          results.push({
            parcelId,
            status: "skipped",
            reason: "unauthorized"
          });
          continue;
        }

        // Log the location
        const courierLocation = `POINT(${lng} ${lat})`;
        const { error: logError } = await supabase
          .from("courier_tracking_logs")
          .insert({
            parcel_id: parcelId,
            courier_id: courierId,
            raw_location: courierLocation,
            is_on_corridor: false, // Conservative default for batch
            via_batch_sync: true,
            created_at: new Date(timestamp).toISOString()
          });

        if (logError) {
          await supabase.from("connectivity_audit").insert({
            courier_id: courierId,
            parcel_id: parcelId,
            lat,
            lng,
            source: "batch_sync_failure",
            reason: "log_failed",
            age_ms: updateAge,
            created_at: new Date().toISOString()
          });
          console.error(`[Tracking.batch-sync] LOG_ERROR: parcelId=${parcelId}, error=${logError.message}`);
          results.push({
            parcelId,
            status: "failed",
            reason: logError.message
          });
        } else {
          console.log(`[Tracking.batch-sync] SYNCED: parcelId=${parcelId}`);
          results.push({
            parcelId,
            status: "synced"
          });
          successCount++;
        }
      } catch (err) {
        console.error(`[Tracking.batch-sync] EXCEPTION: parcelId=${parcelId}, error=${err.message}`);
        results.push({
          parcelId,
          status: "error",
          reason: err.message
        });
      }
    }

    console.log(`[Tracking.batch-sync] COMPLETE: total=${updates.length}, synced=${successCount}`);
    return res.json({
      status: "ok",
      total: updates.length,
      synced: successCount,
      results
    });
  })
);

router.get(
  "/heuristics/:parcelId",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.parcelId;
    const result = await analyzeParcelHeuristics(parcelId);
    if (!result) {
      throw new ApiError("Heuristic data unavailable", 404, "HEURISTIC_NOT_FOUND");
    }
    return res.json(result);
  })
);

router.get(
  "/eta/:parcelId",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.parcelId;
    const eta = await estimateParcelEta(parcelId);
    if (!eta) {
      throw new ApiError("ETA unavailable", 404, "ETA_NOT_FOUND");
    }
    return res.json(eta);
  })
);

module.exports = router;
