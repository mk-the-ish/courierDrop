const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { requireRole } = require("../middleware/auth");

const router = express.Router();

function deriveState(userRow) {
  if (!userRow?.is_active) return "OFFLINE";
  if (userRow?.current_route_id) return "TRAVELLING";
  return "ONLINE";
}

function parseLatLngString(value) {
  if (!value || typeof value !== "string") return null;
  const parts = value
    .split(",")
    .map((part) => Number.parseFloat(part.trim()))
    .filter((part) => Number.isFinite(part));
  if (parts.length !== 2) return null;
  return { lat: parts[0], lng: parts[1] };
}

function toPointWkt(point) {
  if (!point || !Number.isFinite(point.lat) || !Number.isFinite(point.lng)) {
    return null;
  }
  return `SRID=4326;POINT(${point.lng} ${point.lat})`;
}

function toLineWkt(points) {
  if (!Array.isArray(points) || points.length < 2) return null;
  const segments = [];
  for (const point of points) {
    if (!Number.isFinite(point?.lat) || !Number.isFinite(point?.lng)) {
      return null;
    }
    segments.push(`${point.lng} ${point.lat}`);
  }
  return `SRID=4326;LINESTRING(${segments.join(",")})`;
}

router.get(
  "/state",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("users")
      .select("id,is_active,current_route_id")
      .eq("id", courierId)
      .maybeSingle();
    if (error) {
      throw new ApiError(error.message, 500, "COURIER_STATE_FETCH_FAILED");
    }
    const userRow = data || { id: courierId, is_active: true, current_route_id: null };
    return res.json({
      state: deriveState(userRow),
      is_active: Boolean(userRow.is_active),
      current_route_id: userRow.current_route_id
    });
  })
);

router.post(
  "/set-online",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const { online } = req.body || {};
    if (typeof online !== "boolean") {
      throw new ApiError("online boolean required", 400, "COURIER_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { data: userRow, error: fetchError } = await supabase
      .from("users")
      .select("id,is_active,current_route_id")
      .eq("id", courierId)
      .maybeSingle();
    if (fetchError) {
      throw new ApiError(fetchError.message, 500, "COURIER_STATE_FETCH_FAILED");
    }
    if (!userRow) {
      throw new ApiError("Courier profile not found", 404, "COURIER_NOT_FOUND");
    }

    if (!online && userRow.current_route_id) {
      throw new ApiError(
        "Cannot go offline while travelling. End travel first.",
        409,
        "COURIER_TRAVEL_ACTIVE"
      );
    }

    const { data, error } = await supabase
      .from("users")
      .update({
        is_active: online,
        updated_at: new Date().toISOString()
      })
      .eq("id", courierId)
      .select("id,is_active,current_route_id")
      .maybeSingle();
    if (error) {
      throw new ApiError(error.message, 500, "COURIER_STATE_UPDATE_FAILED");
    }
    return res.json({
      state: deriveState(data),
      is_active: Boolean(data?.is_active),
      current_route_id: data?.current_route_id || null
    });
  })
);

router.post(
  "/start-travel",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const { corridorId } = req.body || {};
    if (!corridorId) {
      throw new ApiError("corridorId required", 400, "COURIER_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { data: userRow, error: userErr } = await supabase
      .from("users")
      .select("id,is_active,current_route_id")
      .eq("id", courierId)
      .maybeSingle();
    if (userErr) {
      throw new ApiError(userErr.message, 500, "COURIER_STATE_FETCH_FAILED");
    }
    if (!userRow) {
      throw new ApiError("Courier profile not found", 404, "COURIER_NOT_FOUND");
    }
    if (!userRow.is_active) {
      throw new ApiError("Courier must be ONLINE before travelling", 409, "COURIER_OFFLINE");
    }
    if (userRow.current_route_id) {
      throw new ApiError("Courier already travelling", 409, "COURIER_ALREADY_TRAVELLING");
    }

    const { data: corridor, error: corridorErr } = await supabase
      .from("corridors")
      .select("id,created_by,start_point")
      .eq("id", corridorId)
      .maybeSingle();
    if (corridorErr) {
      throw new ApiError(corridorErr.message, 500, "CORRIDOR_LOOKUP_FAILED");
    }
    if (!corridor || corridor.created_by !== courierId) {
      throw new ApiError("Corridor not found for courier", 404, "CORRIDOR_NOT_FOUND");
    }

    const { data: updated, error: updateErr } = await supabase
      .from("users")
      .update({
        current_route_id: corridorId,
        is_active: true,
        updated_at: new Date().toISOString()
      })
      .eq("id", courierId)
      .select("id,is_active,current_route_id")
      .maybeSingle();
    if (updateErr) {
      throw new ApiError(updateErr.message, 500, "COURIER_START_TRAVEL_FAILED");
    }

    return res.json({
      state: deriveState(updated),
      current_route_id: updated?.current_route_id
    });
  })
);

router.post(
  "/end-travel",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const supabase = getSupabase();
    const { data: updated, error } = await supabase
      .from("users")
      .update({
        current_route_id: null,
        is_active: true,
        updated_at: new Date().toISOString()
      })
      .eq("id", courierId)
      .select("id,is_active,current_route_id")
      .maybeSingle();
    if (error) {
      throw new ApiError(error.message, 500, "COURIER_END_TRAVEL_FAILED");
    }
    return res.json({
      state: deriveState(updated),
      current_route_id: null
    });
  })
);

router.post(
  "/route-templates",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const {
      startLocation,
      endLocation,
      startPlaceName,
      endPlaceName,
      polylinePoints,
      allowMultipleParcels,
      declaredEtaMinutes,
      notes
    } = req.body || {};

    if (!startLocation || !endLocation || !Array.isArray(polylinePoints) || polylinePoints.length < 2) {
      throw new ApiError(
        "startLocation, endLocation and polylinePoints (>=2) required",
        400,
        "ROUTE_TEMPLATE_INVALID_INPUT"
      );
    }

    const start = parseLatLngString(startLocation);
    const end = parseLatLngString(endLocation);
    const lineWkt = toLineWkt(polylinePoints);
    if (!start || !end || !lineWkt) {
      throw new ApiError("Invalid coordinates supplied", 400, "ROUTE_TEMPLATE_INVALID_COORDINATES");
    }

    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("route_templates")
      .insert({
        courier_id: courierId,
        start_location: startLocation,
        end_location: endLocation,
        start_place_name: startPlaceName || null,
        end_place_name: endPlaceName || null,
        start_point: toPointWkt(start),
        end_point: toPointWkt(end),
        route_line: lineWkt,
        allow_multiple_parcels: Boolean(allowMultipleParcels),
        declared_eta_minutes: Number.isFinite(declaredEtaMinutes) ? declaredEtaMinutes : 45,
        notes: notes || null,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select("id")
      .single();

    if (error) {
      throw new ApiError(error.message, 500, "ROUTE_TEMPLATE_CREATE_FAILED");
    }
    return res.status(201).json({ id: data.id });
  })
);

router.get(
  "/route-templates",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("route_templates")
      .select(
        "id,start_location,end_location,allow_multiple_parcels,declared_eta_minutes,notes,created_at,updated_at"
      )
      .eq("courier_id", courierId)
      .order("created_at", { ascending: false });
    if (error) {
      throw new ApiError(error.message, 500, "ROUTE_TEMPLATE_LIST_FAILED");
    }
    return res.json({ templates: data || [] });
  })
);

router.post(
  "/routes/from-template",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const { routeTemplateId, plannedStartAt } = req.body || {};
    if (!routeTemplateId || !plannedStartAt) {
      throw new ApiError("routeTemplateId and plannedStartAt required", 400, "ROUTE_TEMPLATE_USE_INVALID_INPUT");
    }

    const supabase = getSupabase();
    const { data: template, error: templateError } = await supabase
      .from("route_templates")
      .select("*")
      .eq("id", routeTemplateId)
      .eq("courier_id", courierId)
      .maybeSingle();
    if (templateError) {
      throw new ApiError(templateError.message, 500, "ROUTE_TEMPLATE_LOOKUP_FAILED");
    }
    if (!template) {
      throw new ApiError("Route template not found", 404, "ROUTE_TEMPLATE_NOT_FOUND");
    }

    const planned = new Date(plannedStartAt);
    if (Number.isNaN(planned.getTime())) {
      throw new ApiError("plannedStartAt must be valid ISO datetime", 400, "ROUTE_TEMPLATE_USE_INVALID_TIME");
    }
    const etaMin = Math.max(5, Number(template.declared_eta_minutes || 45));
    const end = new Date(planned.getTime() + etaMin * 60 * 1000);
    const nowIso = new Date().toISOString();

    const { data: corridorRow, error: corridorError } = await supabase
      .from("corridors")
      .insert({
        created_by: courierId,
        start_location: template.start_location,
        end_location: template.end_location,
        start_place_name: template.start_place_name || null,
        end_place_name: template.end_place_name || null,
        start_point: template.start_point,
        end_point: template.end_point,
        corridor_line: template.route_line,
        window_start: planned.toISOString(),
        window_end: end.toISOString(),
        allow_multiple_parcels: Boolean(template.allow_multiple_parcels),
        notes: template.notes || null,
        request_id: req.requestId || null,
        created_at: nowIso
      })
      .select("id")
      .single();
    if (corridorError) {
      throw new ApiError(corridorError.message, 500, "ROUTE_TEMPLATE_CORRIDOR_CREATE_FAILED");
    }

    const { data: routeRow, error: routeError } = await supabase
      .from("routes")
      .insert({
        courier_id: courierId,
        corridor_id: corridorRow.id,
        start_point: template.start_point,
        end_point: template.end_point,
        planned_start_at: planned.toISOString(),
        declared_eta_minutes: etaMin,
        status: "PLANNED",
        metadata: { routeTemplateId: template.id },
        created_at: nowIso,
        updated_at: nowIso
      })
      .select("id,status,planned_start_at,corridor_id")
      .single();
    if (routeError) {
      throw new ApiError(routeError.message, 500, "ROUTE_TEMPLATE_ROUTE_CREATE_FAILED");
    }

    return res.status(201).json({
      corridorId: corridorRow.id,
      routeId: routeRow.id,
      status: routeRow.status
    });
  })
);

router.post(
  "/routes",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const { corridorId, plannedStartAt, declaredEtaMinutes } = req.body || {};
    if (!corridorId) {
      throw new ApiError("corridorId required", 400, "ROUTE_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { data: corridor, error: cErr } = await supabase
      .from("corridors")
      .select("id,start_point,end_point,created_by")
      .eq("id", corridorId)
      .maybeSingle();
    if (cErr) throw new ApiError(cErr.message, 500, "ROUTE_CORRIDOR_LOOKUP_FAILED");
    if (!corridor || corridor.created_by !== courierId) {
      throw new ApiError("Corridor not found for courier", 404, "ROUTE_CORRIDOR_NOT_FOUND");
    }
    const { data, error } = await supabase
      .from("routes")
      .insert({
        courier_id: courierId,
        corridor_id: corridorId,
        start_point: corridor.start_point,
        end_point: corridor.end_point,
        planned_start_at: plannedStartAt || null,
        declared_eta_minutes: declaredEtaMinutes || null,
        status: "PLANNED",
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select("*")
      .single();
    if (error) throw new ApiError(error.message, 500, "ROUTE_CREATE_FAILED");
    return res.status(201).json({ route: data });
  })
);

router.get(
  "/routes",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("routes")
      .select("*")
      .eq("courier_id", courierId)
      .order("created_at", { ascending: false })
      .limit(100);
    if (error) throw new ApiError(error.message, 500, "ROUTE_LIST_FAILED");
    return res.json({ routes: data || [] });
  })
);

router.patch(
  "/routes/:routeId",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const routeId = req.params.routeId;
    const { action } = req.body || {};
    if (!["activate", "complete", "cancel"].includes(action)) {
      throw new ApiError("action must be activate|complete|cancel", 400, "ROUTE_INVALID_ACTION");
    }
    const supabase = getSupabase();
    const patch = { updated_at: new Date().toISOString() };
    if (action === "activate") {
      patch.status = "ACTIVE";
      patch.activated_at = new Date().toISOString();
    } else if (action === "complete") {
      patch.status = "COMPLETED";
      patch.completed_at = new Date().toISOString();
    } else {
      patch.status = "CANCELLED";
    }
    const { data, error } = await supabase
      .from("routes")
      .update(patch)
      .eq("id", routeId)
      .eq("courier_id", courierId)
      .select("*")
      .maybeSingle();
    if (error) throw new ApiError(error.message, 500, "ROUTE_UPDATE_FAILED");
    if (!data) throw new ApiError("Route not found", 404, "ROUTE_NOT_FOUND");
    return res.json({ route: data });
  })
);

module.exports = router;
