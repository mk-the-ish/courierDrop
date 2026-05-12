const { getSupabase } = require("../supabase");

const PULSE_GAP_WARN_MS = 120 * 1000;

/**
 * Log large gaps between tracking pulses for dead-zone analysis.
 */
async function connectivityAudit({
  courierId,
  parcelId,
  lat,
  lng,
  lastPulseAt,
  currentPulseAt,
  networkInfo
}) {
  if (!lastPulseAt || !currentPulseAt) {
    return;
  }
  const gapMs = new Date(currentPulseAt).getTime() - new Date(lastPulseAt).getTime();
  if (!Number.isFinite(gapMs) || gapMs < PULSE_GAP_WARN_MS) {
    return;
  }
  const supabase = getSupabase();
  if (!supabase) {
    return;
  }
  await supabase.from("connectivity_audit").insert({
    courier_id: courierId,
    parcel_id: parcelId,
    lat: typeof lat === "number" ? lat : null,
    lng: typeof lng === "number" ? lng : null,
    source: "tracking_pulse_gap",
    reason: "pulse_interval_exceeded",
    age_ms: gapMs,
    metadata: {
      lastPulseAt,
      currentPulseAt,
      network: networkInfo || {}
    },
    created_at: new Date().toISOString()
  });
}

module.exports = {
  connectivityAudit,
  PULSE_GAP_WARN_MS
};
