const { WebSocketServer } = require("ws");
const { getFirebaseAuth } = require("./firebase");
const { getSupabase } = require("./supabase");

const subscribers = new Map();

function addSubscriber(parcelId, ws) {
  const set = subscribers.get(parcelId) || new Set();
  set.add(ws);
  subscribers.set(parcelId, set);
}

function removeSubscriber(parcelId, ws) {
  const set = subscribers.get(parcelId);
  if (!set) return;
  set.delete(ws);
  if (set.size === 0) {
    subscribers.delete(parcelId);
  }
}

function broadcastParcelStatus(parcelId, payload) {
  const set = subscribers.get(parcelId);
  if (!set) return;
  const message = JSON.stringify({ type: "parcel_status", payload });
  for (const ws of set) {
    if (ws.readyState === ws.OPEN) {
      ws.send(message);
    }
  }
}

function broadcastHandshakeEvent(parcelId, payload) {
  const set = subscribers.get(parcelId);
  if (!set) return;
  const message = JSON.stringify({ type: "handshake_event", payload });
  for (const ws of set) {
    if (ws.readyState === ws.OPEN) {
      ws.send(message);
    }
  }
}

function hasRole(user, role) {
  const userRole = user?.role || user?.roles || user?.claims?.role || user?.claims?.roles;
  if (!userRole) return false;
  const roles = Array.isArray(userRole) ? userRole : [userRole];
  return roles.includes(role);
}

async function canAccessParcel(parcelId, user) {
  if (hasRole(user, "admin")) {
    return true;
  }
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from("parcels")
    .select("created_by,assigned_courier_id")
    .eq("id", parcelId)
    .maybeSingle();
  if (error || !data) {
    return false;
  }
  return data.created_by === user?.uid || data.assigned_courier_id === user?.uid;
}

function parseQuery(url) {
  const query = {};
  const index = url.indexOf("?");
  if (index === -1) return query;
  const params = new URLSearchParams(url.slice(index + 1));
  for (const [key, value] of params.entries()) {
    query[key] = value;
  }
  return query;
}

function initWebSocket(server) {
  const wss = new WebSocketServer({ server, path: "/ws" });

  wss.on("connection", async (ws, req) => {
    try {
      const query = parseQuery(req.url || "");
      const parcelId = query.parcelId;
      const authHeader = req.headers.authorization || "";
      const token = authHeader.startsWith("Bearer ")
        ? authHeader.slice(7)
        : "";
      if (!parcelId || !token) {
        ws.close(1008, "parcelId and bearer token required");
        return;
      }
      const firebaseAuth = getFirebaseAuth();
      if (!firebaseAuth) {
        ws.close(1011, "Firebase admin not configured");
        return;
      }
      const decoded = await firebaseAuth.verifyIdToken(token);
      const allowed = await canAccessParcel(parcelId, decoded);
      if (!allowed) {
        ws.close(1008, "Forbidden");
        return;
      }
      addSubscriber(parcelId, ws);

      ws.on("close", () => removeSubscriber(parcelId, ws));
    } catch (_error) {
      ws.close(1008, "Invalid token");
    }
  });

  return wss;
}

module.exports = {
  initWebSocket,
  broadcastParcelStatus,
  broadcastHandshakeEvent
};
