const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { requireRole } = require("../middleware/auth");

const router = express.Router();
const conflictAttempts = new Map();
const CONFLICT_WINDOW_MS = 10 * 60 * 1000;
const CONFLICT_MAX = 5;

function checkConflictRateLimit(key) {
  const now = Date.now();
  const bucket = conflictAttempts.get(key) || [];
  const recent = bucket.filter((timestamp) => now - timestamp < CONFLICT_WINDOW_MS);
  if (recent.length >= CONFLICT_MAX) {
    return false;
  }
  recent.push(now);
  conflictAttempts.set(key, recent);
  return true;
}

function hasRole(user, role) {
  const userRole = user?.role || user?.roles || user?.claims?.role || user?.claims?.roles;
  if (!userRole) return false;
  const roles = Array.isArray(userRole) ? userRole : [userRole];
  return roles.includes(role);
}

async function ensureParcelAccess(supabase, parcelId, user) {
  const { data, error } = await supabase
    .from("parcels")
    .select("created_by,assigned_courier_id")
    .eq("id", parcelId)
    .maybeSingle();
  if (error) {
    throw new ApiError(error.message, 500, "PARCEL_LOOKUP_FAILED");
  }
  if (!data) {
    throw new ApiError("Parcel not found", 404, "PARCEL_NOT_FOUND");
  }
  const uid = user?.uid;
  if (hasRole(user, "admin")) {
    return data;
  }
  if (data.created_by === uid || data.assigned_courier_id === uid) {
    return data;
  }
  throw new ApiError("Not permitted to access parcel", 403, "PARCEL_FORBIDDEN");
}

router.post(
  "/",
  asyncHandler(async (req, res) => {
  const { origin, destination, size, priority, fragile, notes, clientId } =
    req.body || {};

    if (!origin || !destination || !priority) {
      throw new ApiError("Missing required fields", 400, "PARCEL_INVALID_INPUT");
    }

  const supabase = getSupabase();
  if (clientId) {
    const { data: existing, error: lookupError } = await supabase
      .from("parcels")
      .select("created_by")
      .eq("id", clientId)
      .maybeSingle();

    if (lookupError) {
      throw new ApiError(lookupError.message, 500, "PARCEL_LOOKUP_FAILED");
    }

    if (existing && existing.created_by && existing.created_by !== req.user?.uid) {
      const rateKey = `parcel:${req.user?.uid || "anon"}`;
      if (!checkConflictRateLimit(rateKey)) {
        throw new ApiError(
          "Too many conflict attempts. Try again later.",
          429,
          "PARCEL_CONFLICT_RATE_LIMIT"
        );
      }
      throw new ApiError(
        "clientId already used by another user",
        409,
        "PARCEL_CONFLICT"
      );
    }
  }

  // Parse coordinates from "latitude, longitude" string format
  const parseCoordinates = (coordString) => {
    if (!coordString) return null;
    const parts = coordString.trim().split(",").map((s) => parseFloat(s.trim()));
    if (parts.length !== 2 || parts.some((p) => isNaN(p))) return null;
    const [lat, lng] = parts;
    // PostGIS expects POINT(longitude latitude)
    return { lat, lng };
  };

  const originCoords = parseCoordinates(origin);
  const destCoords = parseCoordinates(destination);

  if (!originCoords) {
    throw new ApiError("Invalid origin coordinates format. Expected 'latitude, longitude'", 400, "PARCEL_INVALID_ORIGIN");
  }

  if (!destCoords) {
    throw new ApiError("Invalid destination coordinates format. Expected 'latitude, longitude'", 400, "PARCEL_INVALID_DESTINATION");
  }

  const payload = {
    ...(clientId ? { id: clientId } : {}),
    origin,
    destination,
    origin_point: `POINT(${originCoords.lng} ${originCoords.lat})`,
    destination_point: `POINT(${destCoords.lng} ${destCoords.lat})`,
    size: size || null,
    priority,
    fragile: Boolean(fragile),
    notes: notes || null,
    created_by: req.user?.uid || null,
    request_id: req.requestId || null
  };

  const { data, error } = await supabase
    .from("parcels")
    .upsert(payload, { onConflict: "id" })
    .select("id");

    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_INSERT_FAILED");
    }

    return res.status(201).json({ id: data?.[0]?.id });
  })
);

router.get(
  "/:id",
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const supabase = getSupabase();
    await ensureParcelAccess(supabase, parcelId, req.user);
    const { data, error } = await supabase
      .from("parcels")
      .select(
        "id,status,pickup_verified_at,dropoff_verified_at,created_at,pickup_photo_url,dropoff_photo_url,assigned_courier_id,assigned_at,created_by,pickup_point"
      )
      .eq("id", parcelId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_LOOKUP_FAILED");
    }
    if (!data) {
      throw new ApiError("Parcel not found", 404, "PARCEL_NOT_FOUND");
    }

    const canSeePickup =
      data.assigned_courier_id === req.user?.uid || data.created_by === req.user?.uid || hasRole(req.user, "admin");
    const parcel = {
      ...data,
      pickup_point: canSeePickup ? data.pickup_point : null
    };
    return res.json({ parcel });
  })
);

router.post(
  "/:id/assign",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const { courierId } = req.body || {};
    if (!courierId) {
      throw new ApiError("courierId required", 400, "PARCEL_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { error } = await supabase
      .from("parcels")
      .update({
        assigned_courier_id: courierId,
        assigned_at: new Date().toISOString()
      })
      .eq("id", parcelId);
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_ASSIGN_FAILED");
    }
    return res.json({ status: "ok", parcelId, courierId });
  })
);

router.post(
  "/:id/request-courier",
  requireRole("client"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const { corridorId, corridorIds } = req.body || {};
    const candidates =
      Array.isArray(corridorIds) && corridorIds.length > 0
        ? corridorIds
        : corridorId
        ? [corridorId]
        : [];
    if (candidates.length === 0) {
      throw new ApiError("corridorId(s) required", 400, "PARCEL_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const queuePayload = candidates.map((id, index) => ({
      parcel_id: parcelId,
      corridor_id: id,
      rank: index + 1,
      status: "PENDING"
    }));
    const { error: queueError } = await supabase
      .from("parcel_assignment_queue")
      .insert(queuePayload);
    if (queueError) {
      throw new ApiError(queueError.message, 500, "ASSIGNMENT_QUEUE_FAILED");
    }

    const { data: corridor, error: corridorError } = await supabase
      .from("corridors")
      .select("id,created_by")
      .eq("id", candidates[0])
      .maybeSingle();
    if (corridorError) {
      throw new ApiError(corridorError.message, 500, "CORRIDOR_LOOKUP_FAILED");
    }
    if (!corridor) {
      throw new ApiError("Corridor not found", 404, "CORRIDOR_NOT_FOUND");
    }
    const { error } = await supabase
      .from("parcels")
      .update({
        assigned_courier_id: corridor.created_by,
        assigned_at: new Date().toISOString(),
        status: "ASSIGNED"
      })
      .eq("id", parcelId);
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_ASSIGN_FAILED");
    }
    const { data: parcel } = await supabase
      .from("parcels")
      .select("created_by")
      .eq("id", parcelId)
      .maybeSingle();
    const { sendToUser, sendToParcelTopic } = require("../utils/notifications");
    if (parcel?.created_by) {
      sendToUser(parcel.created_by, "Courier assigned", "A courier has been assigned.", {
        parcelId
      });
    }
    if (corridor.created_by) {
      sendToUser(corridor.created_by, "New delivery request", "You have a new parcel request.", {
        parcelId
      });
    }
    sendToParcelTopic(parcelId, "Courier assigned", "A courier has been assigned.", {
      parcelId,
      status: "ASSIGNED"
    });
    await supabase
      .from("parcel_assignment_queue")
      .update({ status: "ASSIGNED" })
      .eq("parcel_id", parcelId)
      .eq("corridor_id", candidates[0]);
    return res.json({
      status: "ok",
      parcelId,
      courierId: corridor.created_by
    });
  })
);

router.post(
  "/:id/accept",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const supabase = getSupabase();
    const { data: parcel, error: lookupError } = await supabase
      .from("parcels")
      .select("assigned_courier_id,status")
      .eq("id", parcelId)
      .maybeSingle();
    if (lookupError) {
      throw new ApiError(lookupError.message, 500, "PARCEL_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "PARCEL_NOT_FOUND");
    }
    if (parcel.assigned_courier_id !== req.user?.uid) {
      throw new ApiError("Not assigned to this courier", 403, "PARCEL_NOT_ASSIGNED");
    }
    const { error } = await supabase
      .from("parcels")
      .update({ status: "ACCEPTED" })
      .eq("id", parcelId);
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_ACCEPT_FAILED");
    }
    const { broadcastParcelStatus } = require("../ws");
    broadcastParcelStatus(parcelId, { status: "ACCEPTED", parcelId });
    const { data: parcelInfo } = await supabase
      .from("parcels")
      .select("created_by")
      .eq("id", parcelId)
      .maybeSingle();
    const { sendToUser, sendToParcelTopic } = require("../utils/notifications");
    if (parcelInfo?.created_by) {
      sendToUser(parcelInfo.created_by, "Courier accepted", "Your courier accepted the delivery.", {
        parcelId
      });
    }
    sendToParcelTopic(parcelId, "Courier accepted", "Your courier accepted the delivery.", {
      parcelId,
      status: "ACCEPTED"
    });
    return res.json({ status: "ok", parcelId });
  })
);

router.post(
  "/:id/decline",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const supabase = getSupabase();
    const { data: parcel, error: lookupError } = await supabase
      .from("parcels")
      .select("assigned_courier_id,status")
      .eq("id", parcelId)
      .maybeSingle();
    if (lookupError) {
      throw new ApiError(lookupError.message, 500, "PARCEL_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "PARCEL_NOT_FOUND");
    }
    if (parcel.assigned_courier_id !== req.user?.uid) {
      throw new ApiError("Not assigned to this courier", 403, "PARCEL_NOT_ASSIGNED");
    }
    const { data: currentCorridor } = await supabase
      .from("corridors")
      .select("id")
      .eq("created_by", parcel.assigned_courier_id)
      .maybeSingle();
    if (currentCorridor?.id) {
      await supabase
        .from("parcel_assignment_queue")
        .update({ status: "DECLINED" })
        .eq("parcel_id", parcelId)
        .eq("corridor_id", currentCorridor.id);
    }

    const { data: nextCandidate } = await supabase
      .from("parcel_assignment_queue")
      .select("corridor_id")
      .eq("parcel_id", parcelId)
      .eq("status", "PENDING")
      .order("rank", { ascending: true })
      .maybeSingle();

    if (nextCandidate?.corridor_id) {
      const { data: corridor } = await supabase
        .from("corridors")
        .select("created_by")
        .eq("id", nextCandidate.corridor_id)
        .maybeSingle();
      if (corridor?.created_by) {
        const { error: assignError } = await supabase
          .from("parcels")
          .update({
            assigned_courier_id: corridor.created_by,
            assigned_at: new Date().toISOString(),
            status: "ASSIGNED"
          })
          .eq("id", parcelId);
        if (assignError) {
          throw new ApiError(assignError.message, 500, "PARCEL_ASSIGN_FAILED");
        }
        await supabase
          .from("parcel_assignment_queue")
          .update({ status: "ASSIGNED" })
          .eq("parcel_id", parcelId)
          .eq("corridor_id", nextCandidate.corridor_id);
        const { broadcastParcelStatus } = require("../ws");
        broadcastParcelStatus(parcelId, {
          status: "ASSIGNED",
          parcelId,
          reassigned: true
        });
        const { sendToUser, sendToParcelTopic } = require("../utils/notifications");
        if (corridor?.created_by) {
          sendToUser(corridor.created_by, "New delivery request", "You have a new parcel request.", {
            parcelId
          });
        }
        sendToParcelTopic(parcelId, "Courier reassigned", "Finding a new courier.", {
          parcelId,
          status: "ASSIGNED"
        });
        return res.json({ status: "reassigned", parcelId });
      }
    }
    const { error } = await supabase
      .from("parcels")
      .update({
        assigned_courier_id: null,
        assigned_at: null,
        status: "REQUESTED"
      })
      .eq("id", parcelId);
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_DECLINE_FAILED");
    }
    const { broadcastParcelStatus } = require("../ws");
    broadcastParcelStatus(parcelId, { status: "REQUESTED", parcelId });
    return res.json({ status: "ok", parcelId });
  })
);

router.get(
  "/:id/events",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("handshake_events")
      .select("id,step,status,created_at,actor_id")
      .eq("parcel_id", parcelId)
      .order("created_at", { ascending: false });
    if (error) {
      throw new ApiError(error.message, 500, "EVENTS_FETCH_FAILED");
    }
    return res.json({ events: data || [] });
  })
);

router.post(
  "/:id/unassign",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const supabase = getSupabase();
    const { error } = await supabase
      .from("parcels")
      .update({
        assigned_courier_id: null,
        assigned_at: null
      })
      .eq("id", parcelId);
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_UNASSIGN_FAILED");
    }
    return res.json({ status: "ok", parcelId });
  })
);

router.get(
  "/assigned/me",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("parcels")
      .select(
        "id,status,origin,destination,priority,fragile,assigned_at,created_at,origin_point,destination_point"
      )
      .eq("assigned_courier_id", req.user?.uid || "")
      .order("created_at", { ascending: false });
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_FETCH_FAILED");
    }
    return res.json({ parcels: data || [] });
  })
);

router.post(
  "/:id/checkpoints/generate",
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const { count, radiusMeters } = req.body || {};
    const supabase = getSupabase();
    await ensureParcelAccess(supabase, parcelId, req.user);
    const { error } = await supabase.rpc("generate_parcel_checkpoints", {
      p_parcel_id: parcelId,
      p_count: count ?? 3,
      p_radius_m: radiusMeters ?? 200
    });
    if (error) {
      throw new ApiError(error.message, 500, "CHECKPOINT_GENERATE_FAILED");
    }
    return res.json({ status: "ok" });
  })
);

router.get(
  "/:id/checkpoints",
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const supabase = getSupabase();
    await ensureParcelAccess(supabase, parcelId, req.user);
    const { data: parcel, error: parcelError } = await supabase
      .from("parcels")
      .select("privacy_mode")
      .eq("id", parcelId)
      .maybeSingle();
    if (parcelError) {
      throw new ApiError(parcelError.message, 500, "PARCEL_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "PARCEL_NOT_FOUND");
    }

    const fields = parcel.privacy_mode
      ? "id,sequence,radius_m,reached_at"
      : "id,sequence,radius_m,reached_at,checkpoint_point";

    const { data, error } = await supabase
      .from("parcel_checkpoints")
      .select(fields)
      .eq("parcel_id", parcelId)
      .order("sequence", { ascending: true });
    if (error) {
      throw new ApiError(error.message, 500, "CHECKPOINT_FETCH_FAILED");
    }
    return res.json({ checkpoints: data || [] });
  })
);

router.post(
  "/:id/privacy",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const { privacyMode } = req.body || {};
    if (typeof privacyMode !== "boolean") {
      throw new ApiError("privacyMode must be boolean", 400, "PARCEL_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { error } = await supabase
      .from("parcels")
      .update({ privacy_mode: privacyMode })
      .eq("id", parcelId);
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_UPDATE_FAILED");
    }
    return res.json({ status: "ok", privacyMode });
  })
);

router.post(
  "/:id/checkpoints/verify",
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const { lat, lng } = req.body || {};
    if (typeof lat !== "number" || typeof lng !== "number") {
      throw new ApiError("lat/lng required", 400, "CHECKPOINT_INVALID_INPUT");
    }
    const supabase = getSupabase();
    await ensureParcelAccess(supabase, parcelId, req.user);
    const { data, error } = await supabase
      .from("parcel_checkpoints")
      .select("id,checkpoint_point,radius_m,reached_at")
      .eq("parcel_id", parcelId)
      .order("sequence", { ascending: true });
    if (error) {
      throw new ApiError(error.message, 500, "CHECKPOINT_FETCH_FAILED");
    }
    if (!data || data.length == 0) {
      throw new ApiError("No checkpoints", 404, "CHECKPOINT_NOT_FOUND");
    }

    for (const checkpoint of data) {
      if (checkpoint.reached_at) {
        continue;
      }
      const point = checkpoint.checkpoint_point;
      const wktMatch = point?.toString()?.match(/POINT\\(([-\\d\\.]+) ([-\\d\\.]+)\\)/);
      if (!wktMatch) {
        continue;
      }
      const cLng = Number.parseFloat(wktMatch[1]);
      const cLat = Number.parseFloat(wktMatch[2]);
      const toRad = (deg) => (deg * Math.PI) / 180;
      const dLat = toRad(cLat - lat);
      const dLng = toRad(cLng - lng);
      const lat1 = toRad(lat);
      const lat2 = toRad(cLat);
      const sinDLat = Math.sin(dLat / 2);
      const sinDLng = Math.sin(dLng / 2);
      const h =
        sinDLat * sinDLat +
        Math.cos(lat1) * Math.cos(lat2) * sinDLng * sinDLng;
      const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
      const distance = 6371000 * c;
      if (distance <= (checkpoint.radius_m || 200)) {
        const { error: updateError } = await supabase
          .from("parcel_checkpoints")
          .update({ reached_at: new Date().toISOString() })
          .eq("id", checkpoint.id);
        if (updateError) {
          throw new ApiError(updateError.message, 500, "CHECKPOINT_UPDATE_FAILED");
        }
        return res.json({ status: "ok", checkpointId: checkpoint.id });
      }
    }

    return res.status(403).json({ error: "Outside checkpoint radius", code: "CHECKPOINT_GEOFENCE_FAIL" });
  })
);

module.exports = router;
