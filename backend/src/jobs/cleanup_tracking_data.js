const { getSupabase } = require("../supabase");

const TRACKING_LOG_RETENTION_DAYS = 30;
const DEVIATION_EVENT_RETENTION_DAYS = 90;

async function cleanupTrackingData() {
  const supabase = getSupabase();
  const trackingCutoff = new Date(
    Date.now() - TRACKING_LOG_RETENTION_DAYS * 24 * 60 * 60 * 1000
  ).toISOString();
  const deviationCutoff = new Date(
    Date.now() - DEVIATION_EVENT_RETENTION_DAYS * 24 * 60 * 60 * 1000
  ).toISOString();

  const { error: trackingError } = await supabase
    .from("courier_tracking_logs")
    .delete()
    .lt("created_at", trackingCutoff);
  if (trackingError) {
    console.error(
      "[TrackingCleanup] Failed to cleanup courier_tracking_logs:",
      trackingError.message
    );
  }

  const { error: deviationError } = await supabase
    .from("route_deviation_events")
    .delete()
    .lt("created_at", deviationCutoff);
  if (deviationError) {
    console.error(
      "[TrackingCleanup] Failed to cleanup route_deviation_events:",
      deviationError.message
    );
  }

  console.log(
    `[TrackingCleanup] Completed retention cleanup. tracking<${trackingCutoff}, deviations<${deviationCutoff}`
  );
}

module.exports = {
  cleanupTrackingData
};
