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
