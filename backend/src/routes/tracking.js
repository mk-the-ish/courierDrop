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

const router = express.Router();

const CORRIDOR_TOLERANCE_M = 500;
const BATCH_SYNC_MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours

/**
 * POST /tracking/update
 * High-frequency endpoint for courier location pulses
 * Validates corridor allegiance and calculates progress
 */
router.post(
  "/update",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const { parcelId, lat, lng, accuracy } = req.body || {};
    const courierId = req.user?.uid;

    if (typeof lat !== "number" || typeof lng !== "number" || !parcelId) {
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
        "id,status,destination_point,assigned_courier_id,assigned_at,pickup_verified_at"
      )
      .eq("id", parcelId)
      .maybeSingle();

    if (parcelError) {
      throw new ApiError(parcelError.message, 500, "TRACKING_PARCEL_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "TRACKING_PARCEL_NOT_FOUND");
    }

    // Verify courier is assigned
    if (parcel.assigned_courier_id !== courierId) {
      throw new ApiError(
        "Not assigned to this parcel",
        403,
        "TRACKING_NOT_ASSIGNED"
      );
    }

    // Only track if pickup is verified and delivery not yet complete
    if (!parcel.pickup_verified_at || parcel.status === "COMPLETED") {
      return res.json({ status: "ignored", reason: "parcel_not_in_transit" });
    }

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
        created_at: new Date().toISOString()
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
      console.warn(`[Tracking] Error updating progress for parcel ${parcelId}`);
    }
    broadcastTrackingUpdate(parcelId, {
      parcelId,
      progress_percent: progressPercentage,
      integrity_status: integrityStatus,
      tracking_last_update: new Date().toISOString(),
      on_corridor: isOnCorridor
    });

    return res.json({
      status: "ok",
      progress_percent: progressPercentage,
      on_corridor: isOnCorridor,
      integrity_status: integrityStatus,
      distance_m: distanceToDestination
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

    if (!Array.isArray(updates) || updates.length === 0) {
      throw new ApiError("updates array required", 400, "TRACKING_INVALID_BATCH");
    }

    const supabase = getSupabase();
    const results = [];
    let successCount = 0;

    for (const update of updates) {
      const { parcelId, lat, lng, accuracy, timestamp } = update;

      try {
        // Use same validation as single update endpoint
        if (typeof lat !== "number" || typeof lng !== "number" || !parcelId) {
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
            created_at: new Date(timestamp).toISOString()
          });

        if (logError) {
          results.push({
            parcelId,
            status: "failed",
            reason: logError.message
          });
        } else {
          results.push({
            parcelId,
            status: "synced"
          });
          successCount++;
        }
      } catch (err) {
        results.push({
          parcelId,
          status: "error",
          reason: err.message
        });
      }
    }

    return res.json({
      status: "ok",
      total: updates.length,
      synced: successCount,
      results
    });
  })
);

module.exports = router;
