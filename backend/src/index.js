const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
const crypto = require("crypto");
const http = require("http");
const config = require("./config");
const { authMiddleware, requireUser } = require("./middleware/auth");
const healthRoutes = require("./routes/health");
const authRoutes = require("./routes/auth");
const usersRoutes = require("./routes/users");
const vehicleRoutes = require("./routes/vehicles");
const corridorRoutes = require("./routes/corridors");
const parcelRoutes = require("./routes/parcels");
const matchingRoutes = require("./routes/matching");
const heartbeatRoutes = require("./routes/heartbeats");
const errorLogRoutes = require("./routes/error_logs");
const handshakeRoutes = require("./routes/handshake");
const adminRoutes = require("./routes/admin");
const deviceRoutes = require("./routes/devices");
const trackingRoutes = require("./routes/tracking");
const { initWebSocket } = require("./ws");
const { initializeDefaultJobs, getScheduler } = require("./services/scheduler");

const app = express();

app.use(cors());
app.use(express.json({ limit: "2mb" }));
app.use(morgan("tiny"));
app.use((req, res, next) => {
  const headerId =
    typeof req.headers["x-request-id"] === "string"
      ? req.headers["x-request-id"]
      : null;
  const requestId = headerId || crypto.randomUUID();
  req.requestId = requestId;
  res.setHeader("x-request-id", requestId);
  res.locals.skipRequestIdBody = req.path === "/health/heartbeats";
  const originalJson = res.json.bind(res);
  res.json = (body) => {
    if (res.locals.skipRequestIdBody) {
      return originalJson(body);
    }
    if (body && typeof body === "object" && !Array.isArray(body)) {
      return originalJson({ requestId, ...body });
    }
    return originalJson({ requestId, data: body });
  };
  next();
});

app.use("/health", healthRoutes);
app.use("/auth", authRoutes);

// Public health endpoint
app.get("/", (_req, res) => {
  console.log("[SERVER] 🏥 Health check received");
  res.json({
    status: "ok",
    message: "DropCity API",
    timestamp: new Date().toISOString()
  });
});

app.use(authMiddleware);

app.use("/users", requireUser, usersRoutes);
app.use("/vehicles", requireUser, vehicleRoutes);
app.use("/corridors", requireUser, corridorRoutes);
app.use("/parcels", requireUser, parcelRoutes);
app.use("/matches", requireUser, matchingRoutes);
app.use("/handshake", requireUser, handshakeRoutes);
app.use("/heartbeat", requireUser, heartbeatRoutes);
app.use("/logs", requireUser, errorLogRoutes);
app.use("/admin", requireUser, adminRoutes);
app.use("/devices", requireUser, deviceRoutes);
app.use("/tracking", requireUser, trackingRoutes);

app.use((_req, res) => {
  res.status(404).json({
    error: "Not found",
    code: "NOT_FOUND",
    requestId: res.getHeader("x-request-id")
  });
});

app.use((err, _req, res, _next) => {
  const status = err.status || 500;
  res.status(status).json({
    error: err.message || "Unexpected error",
    code: err.code || "UNKNOWN_ERROR",
    requestId: res.getHeader("x-request-id")
  });
});

const server = http.createServer(app);
initWebSocket(server);

// Initialize scheduler for background jobs
initializeDefaultJobs();
const scheduler = getScheduler();
scheduler.startAll();

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("SIGTERM received, shutting down gracefully...");
  scheduler.stopAll();
  server.close(() => {
    console.log("Server closed");
    process.exit(0);
  });
});

process.on("SIGINT", () => {
  console.log("SIGINT received, shutting down gracefully...");
  scheduler.stopAll();
  server.close(() => {
    console.log("Server closed");
    process.exit(0);
  });
});

server.listen(config.port, () => {
  // eslint-disable-next-line no-console
  console.log(`DropCity API listening on ${config.port}`);
  console.log("[Scheduler] Background job scheduler initialized");
});
