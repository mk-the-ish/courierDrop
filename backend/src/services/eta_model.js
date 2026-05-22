const { getSupabase } = require("../supabase");
const config = require("../config");

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

async function getHistoricalCorridorEta(supabase, corridorId) {
  if (!corridorId) return null;
  const { data, error } = await supabase
    .from("eta_calculations_log")
    .select("eta_minutes")
    .eq("corridor_id", corridorId)
    .order("created_at", { ascending: false })
    .limit(30);
  if (error || !data || data.length === 0) {
    return null;
  }
  const values = data
    .map((x) => Number(x.eta_minutes))
    .filter((x) => Number.isFinite(x) && x > 0);
  if (values.length === 0) return null;
  const avg = values.reduce((a, b) => a + b, 0) / values.length;
  return { minutes: avg, sampleCount: values.length };
}

async function getMapProviderEtaMinutes({ origin, destination }) {
  const apiKey =
    process.env.GOOGLE_MAPS_SERVER_API_KEY ||
    process.env.MAPS_API_KEY ||
    config?.googleMapsServerApiKey ||
    "";
  if (!apiKey || !origin || !destination) {
    return null;
  }

  const originStr = `${origin.lat},${origin.lng}`;
  const destinationStr = `${destination.lat},${destination.lng}`;
  const url =
    `https://maps.googleapis.com/maps/api/directions/json` +
    `?origin=${encodeURIComponent(originStr)}` +
    `&destination=${encodeURIComponent(destinationStr)}` +
    `&departure_time=now&traffic_model=best_guess&key=${encodeURIComponent(apiKey)}`;
  try {
    const response = await fetch(url);
    if (!response.ok) {
      return null;
    }
    const decoded = await response.json();
    const route = decoded?.routes?.[0];
    const leg = route?.legs?.[0];
    const durationSec =
      Number(leg?.duration_in_traffic?.value) || Number(leg?.duration?.value);
    if (!Number.isFinite(durationSec) || durationSec <= 0) {
      return null;
    }
    return durationSec / 60;
  } catch (_) {
    return null;
  }
}

function confidenceFromSources(sourceCount, spreadMinutes) {
  let score = Math.min(1, 0.35 + sourceCount * 0.18);
  if (Number.isFinite(spreadMinutes)) {
    if (spreadMinutes <= 8) score += 0.2;
    else if (spreadMinutes <= 15) score += 0.1;
    else if (spreadMinutes >= 30) score -= 0.15;
  }
  return Number(Math.max(0, Math.min(1, score)).toFixed(3));
}

async function estimateParcelEta(parcelId) {
  if (!parcelId) {
    return null;
  }

  const supabase = getSupabase();
  if (!supabase) {
    return null;
  }

  const { data: parcel, error } = await supabase
    .from("parcels")
    .select("id,assigned_courier_id,pickup_point,dropoff_point,destination_point,client_eta_minutes")
    .eq("id", parcelId)
    .maybeSingle();
  if (error || !parcel) {
    return null;
  }

  const { data: latestLog } = await supabase
    .from("courier_tracking_logs")
    .select("raw_location,created_at,corridor_id")
    .eq("parcel_id", parcelId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  const destination = parsePointWkt(parcel.dropoff_point) || parsePointWkt(parcel.destination_point);
  const current = parsePointWkt(latestLog?.raw_location);

  let distanceEtaMin = null;
  let distanceM = null;
  if (current && destination) {
    distanceM = haversineMeters(current, destination);
    distanceEtaMin = (distanceM / 1000 / BASE_SPEED_KMH) * 60;
  }

  const declaredMin = typeof parcel.client_eta_minutes === "number" ? parcel.client_eta_minutes : null;
  const historical = await getHistoricalCorridorEta(supabase, latestLog?.corridor_id || null);
  const historicalMin = historical?.minutes || null;
  const mapProviderMin = await getMapProviderEtaMinutes({
    origin: current,
    destination,
  });

  const weighted = [];
  if (declaredMin !== null) weighted.push({ source: "declared_eta", minutes: declaredMin, weight: 0.25 });
  if (distanceEtaMin !== null) weighted.push({ source: "distance_baseline", minutes: distanceEtaMin, weight: 0.35 });
  if (historicalMin !== null) weighted.push({ source: "historical_corridor", minutes: historicalMin, weight: 0.3 });
  if (mapProviderMin !== null) weighted.push({ source: "map_provider", minutes: mapProviderMin, weight: 0.2 });

  if (weighted.length === 0) {
    return null;
  }

  const weightSum = weighted.reduce((s, x) => s + x.weight, 0);
  const etaMinutesRaw = weighted.reduce((s, x) => s + x.minutes * x.weight, 0) / weightSum;
  const etaMinutes = Math.max(1, Math.round(etaMinutesRaw));
  const values = weighted.map((x) => x.minutes);
  const spreadMinutes = Math.max(...values) - Math.min(...values);
  const confidenceScore = confidenceFromSources(weighted.length, spreadMinutes);
  const confidence =
    confidenceScore >= 0.8 ? "HIGH" : confidenceScore >= 0.55 ? "MEDIUM" : "LOW";

  const result = {
    parcelId,
    etaMinutes,
    confidence,
    confidenceScore,
    sourceBreakdown: weighted.map((x) => ({
      source: x.source,
      minutes: Math.round(x.minutes),
      weight: x.weight
    })),
    distanceMeters: distanceM ? Math.round(distanceM) : null
  };

  const logPayload = {
    parcel_id: parcelId,
    courier_id: parcel.assigned_courier_id,
    corridor_id: latestLog?.corridor_id || null,
    eta_minutes: etaMinutes,
    confidence,
    confidence_score: confidenceScore,
    breakdown: result.sourceBreakdown,
    distance_meters: result.distanceMeters,
    created_at: new Date().toISOString()
  };
  await supabase.from("eta_calculations_log").insert(logPayload);

  return result;
}

module.exports = {
  estimateParcelEta
};
