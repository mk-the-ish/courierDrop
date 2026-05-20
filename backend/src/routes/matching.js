const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { parseWktPoint } = require("../utils/geo");
const { getEligibleCourierMatches } = require("../services/matching");

const router = express.Router();

function toPoint({ lat, lng }) {
  if (typeof lat !== "number" || typeof lng !== "number") {
    return null;
  }
  return `SRID=4326;POINT(${lng} ${lat})`;
}

router.post(
  "/corridors",
  asyncHandler(async (req, res) => {
    const { origin, destination, maxDetourMeters } = req.body || {};
    const originPoint = toPoint(origin || {});
    const destinationPoint = toPoint(destination || {});

  if (!originPoint || !destinationPoint) {
    throw new ApiError(
      "origin and destination must include numeric lat/lng",
      400,
      "MATCH_INVALID_INPUT"
    );
  }

  const supabase = getSupabase();
  const { data, error } = await supabase.rpc("match_corridors_for_parcel", {
    p_origin: originPoint,
    p_destination: destinationPoint,
    p_max_detour_m: maxDetourMeters ?? 50
  });

    if (error) {
      throw new ApiError(error.message, 500, "MATCH_QUERY_FAILED");
    }

    const matches =
      (data || []).map((row) => ({
        corridor_id: row.corridor_id,
        pickup_fraction: row.pickup_fraction,
        dropoff_fraction: row.dropoff_fraction,
        pickup_point: parseWktPoint(row.pickup_point),
        dropoff_point: parseWktPoint(row.dropoff_point)
      })) || [];

    return res.json({ matches });
  })
);

router.post(
  "/delivery",
  asyncHandler(async (req, res) => {
    const { origin, destination, maxDetourMeters } = req.body || {};
    const originPoint = toPoint(origin || {});
    const destinationPoint = toPoint(destination || {});

  if (!originPoint || !destinationPoint) {
    throw new ApiError(
      "origin and destination must include numeric lat/lng",
      400,
      "MATCH_INVALID_INPUT"
    );
  }

    const matches = await getEligibleCourierMatches({
      origin,
      destination,
      maxDetourMeters: maxDetourMeters ?? 50,
      parcelWeightKg: Number(req.body?.weightKg) || 1
    });

    return res.json({ matches });
  })
);

module.exports = router;
