/**
 * Tracking Validation Job
 * Runs periodically to detect route deviations and alert on stalled deliveries
 */

const { getSupabase } = require("../supabase");
const { enqueueNotification } = require("../services/notification_service");
const { NOTIFICATION_EVENT_TYPES } = require("../services/notification_events");

const OFF_CORRIDOR_ALERT_THRESHOLD_MS = 15 * 60 * 1000; // 15 minutes
const STALLED_PROGRESS_THRESHOLD_MS = 10 * 60 * 1000; // 10 minutes

/**
 * Validate active deliveries for route deviations
 * Called periodically by scheduler
 */
async function validateTrackingHealth() {
  const supabase = getSupabase();

  try {
    // Find all parcels in IN_TRANSIT status
    const { data: inTransitParcels, error: parcelError } = await supabase
      .from("parcels")
      .select("id,assigned_courier_id,pickup_verified_at")
      .eq("status", "IN_TRANSIT");

    if (parcelError) {
      console.error("[TrackingValidation] Error fetching parcels:", parcelError);
      return;
    }

    if (!inTransitParcels || inTransitParcels.length === 0) {
      console.log("[TrackingValidation] No parcels in transit");
      return;
    }

    console.log(
      `[TrackingValidation] Validating ${inTransitParcels.length} parcels`
    );

    let alertsRaised = 0;
    const now = new Date();

    for (const parcel of inTransitParcels) {
      try {
        // Get latest tracking logs for this parcel
        const { data: logs, error: logsError } = await supabase
          .from("courier_tracking_logs")
          .select("id,is_on_corridor,progress_index,created_at")
          .eq("parcel_id", parcel.id)
          .order("created_at", { ascending: false })
          .limit(20);

        if (logsError) {
          console.error(
            `[TrackingValidation] Error fetching logs for parcel ${parcel.id}:`,
            logsError
          );
          continue;
        }

        if (!logs || logs.length === 0) {
          console.warn(
            `[TrackingValidation] No tracking logs for parcel ${parcel.id}`
          );
          continue;
        }

        const latestLog = logs[0];
        const timeOffCorridor = latestLog.is_on_corridor
          ? 0
          : now.getTime() - new Date(latestLog.created_at).getTime();

        // Check for prolonged off-corridor condition
        if (
          !latestLog.is_on_corridor &&
          timeOffCorridor > OFF_CORRIDOR_ALERT_THRESHOLD_MS
        ) {
          // Find when courier went off-corridor
          const offCorridorLog = logs.find((log) => !log.is_on_corridor);
          const goingOffTime = offCorridorLog
            ? new Date(offCorridorLog.created_at).getTime()
            : now.getTime();

          // Check if alert already exists
          const { data: existingAlert } = await supabase
            .from("route_deviation_events")
            .select("id,created_at")
            .eq("parcel_id", parcel.id)
            .eq("deviation_type", "OFF_CORRIDOR_PROLONGED")
            .order("created_at", { ascending: false })
            .limit(1);

          const lastAlert = existingAlert?.[0];
          const shouldCreateNew =
            !lastAlert ||
            now.getTime() - new Date(lastAlert.created_at).getTime() >
              OFF_CORRIDOR_ALERT_THRESHOLD_MS * 2; // Avoid spam

          if (shouldCreateNew) {
            const { error: alertError } = await supabase
              .from("route_deviation_events")
              .insert({
                parcel_id: parcel.id,
                courier_id: parcel.assigned_courier_id,
                deviation_type: "OFF_CORRIDOR_PROLONGED",
                duration_seconds: Math.floor(timeOffCorridor / 1000),
                last_on_corridor_at: new Date(goingOffTime).toISOString(),
                created_at: now.toISOString()
              });

            if (!alertError) {
              alertsRaised++;
              if (parcel.assigned_courier_id) {
                await enqueueNotification({
                  type: NOTIFICATION_EVENT_TYPES.TRACKING_DEVIATION_CRITICAL,
                  title: "Route deviation alert",
                  body: "You have been off-corridor for too long.",
                  recipients: [parcel.assigned_courier_id],
                  entityType: "parcel",
                  entityId: parcel.id,
                  payload: {
                    parcelId: parcel.id,
                    deviationType: "OFF_CORRIDOR_PROLONGED",
                    durationSeconds: Math.floor(timeOffCorridor / 1000)
                  }
                });
              }
              console.log(
                `[TrackingValidation] ⚠️ Route deviation alert for parcel ${parcel.id}: OFF_CORRIDOR for ${Math.floor(timeOffCorridor / 1000)}s`
              );
            }
          }
        }

        // Check for stalled progress (no movement in 10 minutes)
        const oldestRecentLog = logs[logs.length - 1];
        const timeSinceLastUpdate =
          now.getTime() - new Date(latestLog.created_at).getTime();
        const timeWithoutProgress =
          now.getTime() - new Date(oldestRecentLog.created_at).getTime();

        // If no tracking update in 10 minutes, might be stalled
        if (timeSinceLastUpdate > STALLED_PROGRESS_THRESHOLD_MS) {
          const { data: existingStalledAlert } = await supabase
            .from("route_deviation_events")
            .select("id,created_at")
            .eq("parcel_id", parcel.id)
            .eq("deviation_type", "NO_RECENT_TRACKING")
            .order("created_at", { ascending: false })
            .limit(1);

          const shouldCreateStalled =
            !existingStalledAlert?.[0] ||
            now.getTime() - new Date(existingStalledAlert[0].created_at).getTime() >
              STALLED_PROGRESS_THRESHOLD_MS * 2;

          if (shouldCreateStalled) {
            const { error: alertError } = await supabase
              .from("route_deviation_events")
              .insert({
                parcel_id: parcel.id,
                courier_id: parcel.assigned_courier_id,
                deviation_type: "NO_RECENT_TRACKING",
                duration_seconds: Math.floor(timeSinceLastUpdate / 1000),
                last_progress_increase_at: new Date(
                  latestLog.created_at
                ).toISOString(),
                created_at: now.toISOString()
              });

            if (!alertError) {
              alertsRaised++;
              if (parcel.assigned_courier_id) {
                await enqueueNotification({
                  type: NOTIFICATION_EVENT_TYPES.TRACKING_DEVIATION_CRITICAL,
                  title: "Tracking stalled",
                  body: "No recent tracking updates detected.",
                  recipients: [parcel.assigned_courier_id],
                  entityType: "parcel",
                  entityId: parcel.id,
                  payload: {
                    parcelId: parcel.id,
                    deviationType: "NO_RECENT_TRACKING",
                    durationSeconds: Math.floor(timeSinceLastUpdate / 1000)
                  }
                });
              }
              console.log(
                `[TrackingValidation] ⚠️ Tracking stalled for parcel ${parcel.id}: No update for ${Math.floor(timeSinceLastUpdate / 1000)}s`
              );
            }
          }
        }

        // Check for progress regression (only if on corridor)
        if (
          latestLog.is_on_corridor &&
          logs.length >= 2 &&
          typeof latestLog.progress_index === "number"
        ) {
          const previousLog = logs[1];
          const previousProgress = previousLog.progress_index || 0;

          // Small tolerance for GPS noise
          if (latestLog.progress_index < previousProgress - 0.05) {
            console.warn(
              `[TrackingValidation] ⚠️ Progress regression for parcel ${parcel.id}: ${previousProgress.toFixed(2)} → ${latestLog.progress_index.toFixed(2)}`
            );
          }
        }
      } catch (err) {
        console.error(
          `[TrackingValidation] Error processing parcel ${parcel.id}:`,
          err.message
        );
      }
    }

    console.log(
      `[TrackingValidation] ✓ Validation complete. Alerts raised: ${alertsRaised}`
    );
  } catch (error) {
    console.error("[TrackingValidation] Fatal error:", error);
  }
}

module.exports = {
  validateTrackingHealth
};
