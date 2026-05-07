const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { markRead } = require("../services/notification_service");

const router = express.Router();

router.get(
  "/me",
  asyncHandler(async (req, res) => {
    const supabase = getSupabase();
    const status = typeof req.query?.status === "string" ? req.query.status : null;
    const limit = Math.min(100, Math.max(1, Number(req.query?.limit || 20)));
    const offset = Math.max(0, Number(req.query?.offset || 0));

    let query = supabase
      .from("notification_recipients")
      .select("notification_id,status,read_at,delivered_at,created_at")
      .eq("user_id", req.user?.uid)
      .order("created_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (status === "read" || status === "unread") {
      query = query.eq("status", status);
    }

    const { data: recipients, error: recipientsError } = await query;
    if (recipientsError) {
      throw new ApiError(recipientsError.message, 500, "NOTIFICATION_FETCH_FAILED");
    }
    const ids = (recipients || []).map((row) => row.notification_id).filter(Boolean);
    if (ids.length === 0) {
      return res.json({ notifications: [] });
    }

    const { data: notifications, error: notificationsError } = await supabase
      .from("notifications")
      .select("id,type,title,body,entity_type,entity_id,payload,created_at")
      .in("id", ids);
    if (notificationsError) {
      throw new ApiError(notificationsError.message, 500, "NOTIFICATION_FETCH_FAILED");
    }

    const byId = new Map((notifications || []).map((item) => [item.id, item]));
    const merged = recipients
      .map((recipient) => {
        const base = byId.get(recipient.notification_id);
        if (!base) return null;
        return {
          id: base.id,
          type: base.type,
          title: base.title,
          body: base.body,
          entityType: base.entity_type,
          entityId: base.entity_id,
          payload: base.payload || {},
          status: recipient.status,
          createdAt: base.created_at,
          readAt: recipient.read_at,
          deliveredAt: recipient.delivered_at,
          source: "supabase"
        };
      })
      .filter(Boolean);

    return res.json({ notifications: merged });
  })
);

router.post(
  "/:id/read",
  asyncHandler(async (req, res) => {
    const result = await markRead({
      userId: req.user?.uid,
      notificationId: req.params.id
    });
    if (!result.updated) {
      throw new ApiError("Notification not found", 404, "NOTIFICATION_NOT_FOUND");
    }
    return res.json({ status: "ok", notificationId: req.params.id });
  })
);

router.post(
  "/read-all",
  asyncHandler(async (req, res) => {
    const supabase = getSupabase();
    const { data: rows, error } = await supabase
      .from("notification_recipients")
      .select("notification_id")
      .eq("user_id", req.user?.uid)
      .eq("status", "unread")
      .limit(500);
    if (error) {
      throw new ApiError(error.message, 500, "NOTIFICATION_READ_ALL_FAILED");
    }
    let updated = 0;
    for (const row of rows || []) {
      const result = await markRead({
        userId: req.user?.uid,
        notificationId: row.notification_id
      });
      if (result.updated) updated += 1;
    }
    return res.json({ status: "ok", updated });
  })
);

module.exports = router;
