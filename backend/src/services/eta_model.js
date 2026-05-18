const { getSupabase } = require("../supabase");

const BASE_SPEED_KMH = 40;

function toRad(deg) {
  return (deg * Math.PI) / 180;
}

function haversineMeters(a, b) {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

function parsePointWkt(wkt) {
  if (!wkt || typeof wkt !== "string") return null;
  const m = wkt.match(/POINT\(([-\d.]+)\s+([-\d.]+)\)/i);
  if (!m) return null;
  return { lng: Number(m[1]), lat: Number(m[2]) };
}

async function estimateParcelEta(parcelId) {
  const supabase = getSupabase();
  const { data: parcel, error } = await supabase
    .from("parcels")
    .select("id,assigned_courier_id,pickup_point,dropoff_point,destination_point,client_eta_minutes")
    .eq("id", parcelId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!parcel) return null;

  const { data: latestLog } = await supabase
    .from("courier_tracking_logs")
    .select("raw_location,created_at")
    .eq("parcel_id", parcelId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  const destination = parsePointWkt(parcel.dropoff_point || parcel.destination_point);
  const current = parsePointWkt(latestLog?.raw_location);

  let distanceEtaMin = null;
  let distanceM = null;
  if (current && destination) {
    distanceM = haversineMeters(current, destination);
    distanceEtaMin = (distanceM / 1000 / BASE_SPEED_KMH) * 60;
  }

  const declaredMin = typeof parcel.client_eta_minutes === "number" ? parcel.client_eta_minutes : null;
  const historicalMin = distanceEtaMin ? distanceEtaMin * 1.15 : null;

  const weighted = [];
  if (declaredMin !== null) weighted.push({ value: declaredMin, weight: 0.3, source: "declared" });
  if (distanceEtaMin !== null) weighted.push({ value: distanceEtaMin, weight: 0.5, source: "distance_speed" });
  if (historicalMin !== null) weighted.push({ value: historicalMin, weight: 0.2, source: "historical" });

  const weightSum = weighted.reduce((s, x) => s + x.weight, 0) || 1;
  const etaMinutes = weighted.reduce((s, x) => s + x.value * x.weight, 0) / weightSum;

  const confidence =
    weighted.length >= 3 ? "HIGH" : weighted.length === 2 ? "MEDIUM" : "LOW";

  const result = {
    parcelId,
    etaMinutes: Math.max(1, Math.round(etaMinutes || 0)),
    confidence,
    breakdown: weighted.map((x) => ({ source: x.source, minutes: Math.round(x.value) })),
    distanceMeters: distanceM ? Math.round(distanceM) : null
  };

  await supabase.from("eta_calculations_log").insert({
    parcel_id: parcelId,
    courier_id: parcel.assigned_courier_id,
    eta_minutes: result.etaMinutes,
    confidence: result.confidence,
    breakdown: result.breakdown,
    distance_meters: result.distanceMeters,
    created_at: new Date().toISOString()
  });

  return result;
}

module.exports = {
  estimateParcelEta
};
