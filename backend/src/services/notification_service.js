const { getSupabase } = require("../supabase");
const { getFirestore } = require("../firebase");
const { sendToUser } = require("../utils/notifications");

const MAX_OUTBOX_ATTEMPTS = 10;

function notificationDocPath(userId, notificationId) {
  return `users/${userId}/notifications/${notificationId}`;
}

function toFirestoreNotification(notification, status = "unread", readAt = null) {
  return {
    id: notification.id,
    type: notification.type,
    title: notification.title,
    body: notification.body,
    entityType: notification.entity_type || null,
    entityId: notification.entity_id || null,
    payload: notification.payload || {},
    status,
    createdAt: notification.created_at,
    readAt,
    source: "supabase"
  };
}

function backoffSeconds(attempts) {
  return Math.min(3600, 15 * Math.pow(2, Math.max(0, attempts)));
}

async function enqueueNotification({
  type,
  title,
  body,
  recipients,
  entityType,
  entityId,
  payload
}) {
  if (!Array.isArray(recipients) || recipients.length === 0) {
    throw new Error("recipients are required");
  }

  const supabase = getSupabase();
  const { data: notificationRows, error: notificationError } = await supabase
    .from("notifications")
    .insert({
      type,
      title,
      body,
      entity_type: entityType || null,
      entity_id: entityId ? String(entityId) : null,
      payload: payload || {}
    })
    .select("id")
    .limit(1);

  if (notificationError) {
    throw notificationError;
  }

  const notificationId = notificationRows?.[0]?.id;
  if (!notificationId) {
    throw new Error("Failed to create notification");
  }

  const { error: outboxError } = await supabase.from("notification_outbox").insert({
    kind: "notification_fanout",
    payload: {
      notificationId,
      recipients: Array.from(new Set(recipients)),
      requestId: payload?.requestId || null
    },
    status: "pending"
  });
  if (outboxError) {
    throw outboxError;
  }

  return { id: notificationId };
}

async function fanoutNotification(notificationId, recipientsOverride) {
  const supabase = getSupabase();
  const firestore = getFirestore();
  const { data: notification, error: notificationError } = await supabase
    .from("notifications")
    .select("id,type,title,body,entity_type,entity_id,payload,created_at")
    .eq("id", notificationId)
    .maybeSingle();
  if (notificationError) {
    throw notificationError;
  }
  if (!notification) {
    throw new Error(`Notification ${notificationId} not found`);
  }

  const recipients = Array.from(new Set(recipientsOverride || []));
  if (recipients.length === 0) {
    return { delivered: 0 };
  }

  const recipientRows = recipients.map((userId) => ({
    notification_id: notification.id,
    user_id: userId,
    status: "unread",
    delivered_at: new Date().toISOString()
  }));
  const { error: recipientError } = await supabase
    .from("notification_recipients")
    .upsert(recipientRows, { onConflict: "notification_id,user_id" });
  if (recipientError) {
    throw recipientError;
  }

  for (const userId of recipients) {
    if (firestore) {
      await firestore
        .doc(notificationDocPath(userId, notification.id))
        .set(toFirestoreNotification(notification), { merge: true });
    }
    await sendToUser(userId, notification.title, notification.body, {
      notificationId: notification.id,
      type: notification.type,
      entityType: notification.entity_type || "",
      entityId: notification.entity_id || ""
    });
  }

  return { delivered: recipients.length };
}

async function processOutboxBatch(limit = 100) {
  const supabase = getSupabase();
  const nowIso = new Date().toISOString();
  const { data: outboxRows, error } = await supabase
    .from("notification_outbox")
    .select("id,kind,payload,status,attempts")
    .in("status", ["pending", "retry"])
    .lte("run_after", nowIso)
    .order("created_at", { ascending: true })
    .limit(limit);
  if (error) {
    throw error;
  }

  const summary = { processed: 0, success: 0, failed: 0 };
  for (const row of outboxRows || []) {
    const requestId = row.payload?.requestId || "n/a";
    summary.processed += 1;
    try {
      if (row.kind === "notification_fanout") {
        await fanoutNotification(row.payload?.notificationId, row.payload?.recipients);
      }
      console.log(
        `[NotificationPipeline][${requestId}] delivered notification=${row.payload?.notificationId}`
      );
      const { error: doneError } = await supabase
        .from("notification_outbox")
        .update({
          status: "processed",
          attempts: (row.attempts || 0) + 1,
          processed_at: new Date().toISOString(),
          last_error: null
        })
        .eq("id", row.id);
      if (doneError) {
        throw doneError;
      }
      summary.success += 1;
    } catch (err) {
      const attempts = (row.attempts || 0) + 1;
      const terminal = attempts >= MAX_OUTBOX_ATTEMPTS;
      const updatePayload = terminal
        ? {
            status: "dead_letter",
            attempts,
            last_error: err.message || String(err),
            processed_at: new Date().toISOString()
          }
        : {
            status: "retry",
            attempts,
            last_error: err.message || String(err),
            run_after: new Date(Date.now() + backoffSeconds(attempts) * 1000).toISOString()
          };
      console.error(
        `[NotificationPipeline][${requestId}] failure notification=${row.payload?.notificationId} attempts=${attempts} error=${err.message}`
      );
      await supabase.from("notification_outbox").update(updatePayload).eq("id", row.id);
      summary.failed += 1;
    }
  }
  return summary;
}

async function markRead({ userId, notificationId }) {
  const supabase = getSupabase();
  const firestore = getFirestore();
  const readAt = new Date().toISOString();
  const { data, error } = await supabase
    .from("notification_recipients")
    .update({
      status: "read",
      read_at: readAt
    })
    .eq("notification_id", notificationId)
    .eq("user_id", userId)
    .select("notification_id")
    .limit(1);
  if (error) {
    throw error;
  }
  if (!data || data.length === 0) {
    return { updated: false };
  }

  if (firestore) {
    await firestore.doc(notificationDocPath(userId, notificationId)).set(
      {
        status: "read",
        readAt
      },
      { merge: true }
    );
  }
  return { updated: true };
}

module.exports = {
  enqueueNotification,
  processOutboxBatch,
  fanoutNotification,
  markRead
};
