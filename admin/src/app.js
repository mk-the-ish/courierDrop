const baseUrlInput = document.getElementById("baseUrl");
const tokenInput = document.getElementById("token");
const parcelIdInput = document.getElementById("parcelId");
const privacyToggle = document.getElementById("privacyToggle");
const applyBtn = document.getElementById("applyBtn");
const statusEl = document.getElementById("status");
const eventParcelId = document.getElementById("eventParcelId");
const fetchEventsBtn = document.getElementById("fetchEventsBtn");
const eventsEl = document.getElementById("events");
const retentionDaysInput = document.getElementById("retentionDays");
const runCleanupBtn = document.getElementById("runCleanupBtn");
const cleanupStatus = document.getElementById("cleanupStatus");
const fetchHeartbeatsBtn = document.getElementById("fetchHeartbeatsBtn");
const heartbeatList = document.getElementById("heartbeatList");
const heartbeatStatus = document.getElementById("heartbeatStatus");
let heartbeatIntervalId = null;
const fetchParcelsBtn = document.getElementById("fetchParcelsBtn");
const parcelStatus = document.getElementById("parcelStatus");
const parcelList = document.getElementById("parcelList");
const parcelStatusFilter = document.getElementById("parcelStatusFilter");
const parcelAssignFilter = document.getElementById("parcelAssignFilter");
let parcelIntervalId = null;
let parcelCache = [];

function setStatus(message, isError = false) {
  statusEl.textContent = message;
  statusEl.style.color = isError ? "#b91c1c" : "#0f766e";
}

async function applyPrivacyMode() {
  const baseUrl = baseUrlInput.value.trim();
  const token = tokenInput.value.trim();
  const parcelId = parcelIdInput.value.trim();
  const privacyMode = privacyToggle.checked;

  if (!baseUrl || !token || !parcelId) {
    setStatus("Base URL, token, and parcel ID are required.", true);
    return;
  }

  applyBtn.disabled = true;
  setStatus("Updating privacy mode...");
  try {
    const response = await fetch(`${baseUrl}/parcels/${parcelId}/privacy`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`
      },
      body: JSON.stringify({ privacyMode })
    });
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.error || "Failed to update privacy mode");
    }
    setStatus(`Privacy mode set to ${privacyMode ? "ON" : "OFF"}.`);
  } catch (error) {
    setStatus(error.message, true);
  } finally {
    applyBtn.disabled = false;
  }
}

applyBtn.addEventListener("click", applyPrivacyMode);

async function fetchHandshakeEvents() {
  const baseUrl = baseUrlInput.value.trim();
  const token = tokenInput.value.trim();
  const parcelId = eventParcelId.value.trim();
  if (!baseUrl || !token || !parcelId) {
    setStatus("Base URL, token, and parcel ID are required.", true);
    return;
  }
  eventsEl.innerHTML = "";
  try {
    const response = await fetch(`${baseUrl}/parcels/${parcelId}/events`, {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.error || "Failed to fetch events");
    }
    const events = data.events || [];
    if (events.length === 0) {
      eventsEl.textContent = "No events found.";
      return;
    }
    events.forEach((event) => {
      const div = document.createElement("div");
      div.className = "event-item";
      div.textContent = `${event.created_at} | ${event.step} | ${event.status}`;
      eventsEl.appendChild(div);
    });
  } catch (error) {
    setStatus(error.message, true);
  }
}

fetchEventsBtn.addEventListener("click", fetchHandshakeEvents);

async function runCleanup() {
  const baseUrl = baseUrlInput.value.trim();
  const token = tokenInput.value.trim();
  const days = Number(retentionDaysInput.value);
  if (!baseUrl || !token || !days) {
    setStatus("Base URL, token, and retention days are required.", true);
    return;
  }
  cleanupStatus.textContent = "Running cleanup...";
  try {
    const response = await fetch(`${baseUrl}/admin/handshake/cleanup`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`
      },
      body: JSON.stringify({ days })
    });
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.error || "Cleanup failed");
    }
    cleanupStatus.textContent = `Deleted ${data.deleted || 0} events.`;
  } catch (error) {
    cleanupStatus.textContent = error.message;
  }
}

runCleanupBtn.addEventListener("click", runCleanup);

function formatAgo(iso) {
  if (!iso) return "-";
  const time = new Date(iso);
  if (Number.isNaN(time.getTime())) return iso;
  const diffSeconds = Math.floor((Date.now() - time.getTime()) / 1000);
  if (diffSeconds < 60) return `${diffSeconds}s ago`;
  const diffMinutes = Math.floor(diffSeconds / 60);
  if (diffMinutes < 60) return `${diffMinutes}m ago`;
  const diffHours = Math.floor(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d ago`;
}

function heartbeatTone(heartbeat, staleSeconds) {
  const expected = Number(heartbeat.expected_frequency_sec || 0);
  if (heartbeat.status === "STUCK") {
    return "bad";
  }
  if (!expected) {
    return "warn";
  }
  if (staleSeconds > expected * 2) {
    return "bad";
  }
  if (staleSeconds > expected) {
    return "warn";
  }
  return "ok";
}

async function fetchHeartbeats() {
  const baseUrl = baseUrlInput.value.trim();
  const token = tokenInput.value.trim();
  if (!baseUrl) {
    heartbeatStatus.textContent = "Base URL required.";
    return;
  }
  heartbeatStatus.textContent = "Loading...";
  heartbeatList.innerHTML = "";
  try {
    const response = await fetch(`${baseUrl}/health/heartbeats`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {}
    });
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.error || "Failed to fetch heartbeats");
    }
    const heartbeats = data.heartbeats || [];
    if (heartbeats.length === 0) {
      heartbeatStatus.textContent = "No heartbeats yet.";
      return;
    }
    heartbeatStatus.textContent = `Showing ${heartbeats.length} jobs.`;
    heartbeats.forEach((hb) => {
      const last = hb.last_heartbeat_at;
      const expected = Number(hb.expected_frequency_sec || 0);
      const staleSeconds = last
        ? Math.max(0, Math.floor((Date.now() - new Date(last).getTime()) / 1000))
        : 0;
      const tone = heartbeatTone(hb, staleSeconds);
      const item = document.createElement("div");
      item.className = `heartbeat-item ${tone}`;
      item.innerHTML = `
        <div class="heartbeat-name">${hb.job_name || "Unknown job"}</div>
        <div class="heartbeat-meta">
          <span>Status: ${hb.status || "UNKNOWN"}</span>
          <span>Last: ${formatAgo(last)}</span>
          <span>Expected: ${expected || "-"}s</span>
          <span>Stale: ${staleSeconds}s</span>
        </div>
      `;
      heartbeatList.appendChild(item);
    });
  } catch (error) {
    heartbeatStatus.textContent = error.message;
  }
}

fetchHeartbeatsBtn.addEventListener("click", fetchHeartbeats);

function startHeartbeatAutoRefresh() {
  if (heartbeatIntervalId) {
    clearInterval(heartbeatIntervalId);
  }
  fetchHeartbeats();
  heartbeatIntervalId = setInterval(fetchHeartbeats, 30000);
}

startHeartbeatAutoRefresh();

function formatTime(iso) {
  if (!iso) return "-";
  const time = new Date(iso);
  if (Number.isNaN(time.getTime())) return iso;
  return time.toLocaleString();
}

function applyParcelFilters(list) {
  const status = parcelStatusFilter.value;
  const assignment = parcelAssignFilter.value;
  return list.filter((parcel) => {
    if (status !== "all" && parcel.status !== status) {
      return false;
    }
    if (assignment === "assigned" && !parcel.assigned_courier_id) {
      return false;
    }
    if (assignment === "unassigned" && parcel.assigned_courier_id) {
      return false;
    }
    return true;
  });
}

function renderParcels(list) {
  parcelList.innerHTML = "";
  if (list.length === 0) {
    parcelList.textContent = "No parcels match filters.";
    return;
  }
  list.forEach((parcel) => {
    const card = document.createElement("div");
    card.className = "parcel-item";
    const assigned = parcel.assigned_courier_id ? "ASSIGNED" : "UNASSIGNED";
    card.innerHTML = `
      <div class="parcel-row">
        <div>
          <div class="parcel-id">${parcel.id}</div>
          <div class="parcel-meta">${parcel.origin || "-"} → ${parcel.destination || "-"}</div>
        </div>
        <div class="parcel-badges">
          <span class="badge">${parcel.status || "UNKNOWN"}</span>
          <span class="badge ${assigned === "ASSIGNED" ? "ok" : "warn"}">${assigned}</span>
        </div>
      </div>
      <div class="parcel-details">
        <span>Priority: ${parcel.priority || "-"}</span>
        <span>Fragile: ${parcel.fragile ? "Yes" : "No"}</span>
        <span>Created: ${formatTime(parcel.created_at)}</span>
        <span>Assigned at: ${formatTime(parcel.assigned_at)}</span>
      </div>
    `;
    parcelList.appendChild(card);
  });
}

async function fetchParcels() {
  const baseUrl = baseUrlInput.value.trim();
  const token = tokenInput.value.trim();
  if (!baseUrl || !token) {
    parcelStatus.textContent = "Base URL and admin token required.";
    return;
  }
  parcelStatus.textContent = "Loading parcels...";
  try {
    const response = await fetch(`${baseUrl}/admin/parcels`, {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.error || "Failed to fetch parcels");
    }
    parcelCache = data.parcels || [];
    parcelStatus.textContent = `Showing ${parcelCache.length} parcels.`;
    renderParcels(applyParcelFilters(parcelCache));
  } catch (error) {
    parcelStatus.textContent = error.message;
  }
}

function startParcelAutoRefresh() {
  if (parcelIntervalId) {
    clearInterval(parcelIntervalId);
  }
  fetchParcels();
  parcelIntervalId = setInterval(fetchParcels, 30000);
}

fetchParcelsBtn.addEventListener("click", fetchParcels);
parcelStatusFilter.addEventListener("change", () => {
  renderParcels(applyParcelFilters(parcelCache));
});
parcelAssignFilter.addEventListener("change", () => {
  renderParcels(applyParcelFilters(parcelCache));
});

startParcelAutoRefresh();
