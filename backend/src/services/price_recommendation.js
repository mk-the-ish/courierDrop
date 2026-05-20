const { getSupabase } = require("../supabase");

const SIZE_MULTIPLIERS = { S: 0.5, M: 1.0, L: 2.0 };
const URGENCY_MULTIPLIER = { standard: 1.0, express: 1.2, "same-day": 1.35 };

function toRouteKey(originLat, originLng, destinationLat, destinationLng) {
  const round = (v) => Number(v).toFixed(2);
  return `${round(originLat)},${round(originLng)}->${round(destinationLat)},${round(destinationLng)}`;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function defaultResponse(size = "M", weightKg = null) {
  const base = { S: 1.0, M: 1.8, L: 3.0 }[size] || 1.8;
  const weightMultiplier = weightKg && weightKg > 2 ? 1 + Math.min(0.35, (weightKg - 2) * 0.03) : 1;
  const price = Number((base * weightMultiplier).toFixed(2));
  return {
    recommendedPrice: price,
    baseFare: base,
    sizeMultiplier: SIZE_MULTIPLIERS[size] || 1.0,
    corridorName: "DEFAULT",
    components: {
      segmentTransferPct: 1,
      urgencyMultiplier: 1,
      weightMultiplier,
      demandModifier: 1
    }
  };
}

async function getDemandModifier(supabase) {
  const { count } = await supabase
    .from("parcels")
    .select("id", { count: "exact", head: true })
    .in("status", ["REQUESTED", "MATCHING", "ASSIGNED", "IN_TRANSIT"]);
  if (!Number.isFinite(count)) return 1;
  if (count <= 20) return 1.0;
  if (count <= 60) return 1.08;
  if (count <= 120) return 1.16;
  return 1.25;
}

async function getRouteHistoryAdjustment(supabase, routeKey) {
  const { data } = await supabase
    .from("route_pricing_history")
    .select("recommended_price,accepted_price")
    .eq("route_key", routeKey)
    .order("created_at", { ascending: false })
    .limit(20);
  if (!data || data.length === 0) {
    return { multiplier: 1, sampleCount: 0 };
  }
  const ratios = data
    .map((row) => {
      const rec = Number(row.recommended_price);
      const acc = Number(row.accepted_price);
      if (!Number.isFinite(rec) || rec <= 0 || !Number.isFinite(acc) || acc <= 0) return null;
      return acc / rec;
    })
    .filter((x) => x !== null);
  if (ratios.length === 0) {
    return { multiplier: 1, sampleCount: 0 };
  }
  const avg = ratios.reduce((a, b) => a + b, 0) / ratios.length;
  return { multiplier: clamp(avg, 0.85, 1.2), sampleCount: ratios.length };
}

async function getRecommendedPrice(
  originLat,
  originLng,
  destinationLat,
  destinationLng,
  size = "M",
  weightKg = null,
  options = {}
) {
  const supabase = getSupabase();
  if (!supabase || !SIZE_MULTIPLIERS[size]) {
    return defaultResponse(size, weightKg);
  }

  const routeKey = toRouteKey(originLat, originLng, destinationLat, destinationLng);
  const priority = (options.priority || "standard").toString().toLowerCase();
  const urgencyMultiplier = URGENCY_MULTIPLIER[priority] || URGENCY_MULTIPLIER.standard;

  const { data: baseFares } = await supabase
    .from("base_fares")
    .select("*")
    .order("distance_km", { ascending: true })
    .limit(5);
  if (!baseFares || baseFares.length === 0) {
    return defaultResponse(size, weightKg);
  }

  const baseRoute = baseFares[0];
  const baseFare = Number(baseRoute.passenger_fare_usd) || 1.0;
  const distanceKm = Number(baseRoute.distance_km) || 5;

  const requestedDistanceM = Math.max(
    200,
    distanceKm * 1000 * 0.75
  );
  const corridorDistanceM = Math.max(500, distanceKm * 1000);
  const segmentTransferPct = clamp(requestedDistanceM / corridorDistanceM, 0.2, 1.0);
  const weightMultiplier =
    weightKg && Number.isFinite(weightKg)
      ? clamp(1 + Math.max(0, weightKg - 1) * 0.025, 1, 1.5)
      : 1;
  const demandModifier = await getDemandModifier(supabase);
  const historyAdj = await getRouteHistoryAdjustment(supabase, routeKey);

  const sizeFactor = SIZE_MULTIPLIERS[size];
  const recommendedPriceRaw =
    baseFare *
    sizeFactor *
    segmentTransferPct *
    urgencyMultiplier *
    weightMultiplier *
    demandModifier *
    historyAdj.multiplier;
  const recommendedPrice = Number(clamp(recommendedPriceRaw, 0.6, baseFare * 4).toFixed(2));

  const factors = {
    routeKey,
    modelVersion: "v2",
    baseFare,
    sizeFactor,
    segmentTransferPct: Number(segmentTransferPct.toFixed(3)),
    urgencyMultiplier,
    weightMultiplier: Number(weightMultiplier.toFixed(3)),
    demandModifier,
    historicalMultiplier: Number(historyAdj.multiplier.toFixed(3)),
    historySampleCount: historyAdj.sampleCount
  };

  await supabase.from("price_recommendations_log").insert({
    parcel_id: options.parcelId || null,
    corridor_id: options.corridorId || null,
    factors,
    recommended_price: recommendedPrice,
    model_version: "v2",
    created_at: new Date().toISOString()
  });

  await supabase.from("route_pricing_history").insert({
    route_key: routeKey,
    corridor_id: options.corridorId || null,
    parcel_id: options.parcelId || null,
    distance_meters: requestedDistanceM,
    weight_kg: weightKg && Number.isFinite(weightKg) ? weightKg : null,
    size_code: size,
    recommended_price: recommendedPrice,
    accepted_price: options.acceptedPrice && Number.isFinite(options.acceptedPrice) ? options.acceptedPrice : null,
    created_at: new Date().toISOString()
  });

  return {
    recommendedPrice,
    baseFare,
    sizeMultiplier: sizeFactor,
    distanceKm,
    corridorName: baseRoute.corridor_name,
    components: factors
  };
}

function validateUserPrice(recommendedPrice, userPrice, tolerance = 0.35) {
  const minAcceptable = recommendedPrice * (1 - tolerance);
  const maxAcceptable = recommendedPrice * (1 + tolerance);
  return {
    isAcceptable: userPrice >= minAcceptable && userPrice <= maxAcceptable,
    minPrice: Number(minAcceptable.toFixed(2)),
    maxPrice: Number(maxAcceptable.toFixed(2)),
    recommendedPrice: Number(recommendedPrice.toFixed(2)),
    deviation: Number((((userPrice - recommendedPrice) / recommendedPrice) * 100).toFixed(2))
  };
}

module.exports = {
  getRecommendedPrice,
  validateUserPrice,
  SIZE_MULTIPLIERS
};

