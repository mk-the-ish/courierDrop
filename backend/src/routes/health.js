const express = require("express");
const { getSupabase } = require("../supabase");
const { getScheduler } = require("../services/scheduler");

const router = express.Router();

router.get("/", async (_req, res) => {
  res.json({
    status: "ok",
    service: "dropcity-backend",
    timestamp: new Date().toISOString()
  });
});

router.get("/heartbeats", async (_req, res) => {
  const supabase = getSupabase();

  if (!supabase) {
    return res.status(500).json({ error: "Supabase not configured" });
  }

  const { data, error } = await supabase
    .from("job_heartbeats")
    .select("job_name,last_heartbeat_at,expected_frequency_sec,status")
    .order("job_name", { ascending: true });

  if (error) {
    return res.status(500).json({ error: error.message });
  }

  return res.json({
    count: data.length,
    heartbeats: data
  });
});

router.get("/jobs", async (_req, res) => {
  const scheduler = getScheduler();
  const jobsStatus = scheduler.getAllJobsStatus();

  return res.json({
    schedulerRunning: scheduler.isRunning(),
    jobCount: jobsStatus.length,
    jobs: jobsStatus
  });
});

router.get("/status", async (_req, res) => {
  const supabase = getSupabase();
  const scheduler = getScheduler();

  try {
    // Get system metrics
    const { count: totalParcels } = await supabase
      .from("parcels")
      .select("id", { count: "exact", head: true });

    const { count: inTransitCount } = await supabase
      .from("parcels")
      .select("id", { count: "exact", head: true })
      .eq("status", "IN_TRANSIT");

    const { count: deliveredToday } = await supabase
      .from("parcels")
      .select("id", { count: "exact", head: true })
      .eq("status", "DELIVERED")
      .gte("created_at", new Date(new Date().setHours(0, 0, 0, 0)).toISOString());

    const { count: couriersCount } = await supabase
      .from("users")
      .select("id", { count: "exact", head: true })
      .eq("role", "COURIER");

    const jobsStatus = scheduler.getAllJobsStatus();

    return res.json({
      status: "ok",
      timestamp: new Date().toISOString(),
      metrics: {
        totalParcels: totalParcels || 0,
        inTransitParcels: inTransitCount || 0,
        deliveredToday: deliveredToday || 0,
        totalCouriers: couriersCount || 0
      },
      scheduler: {
        running: scheduler.isRunning(),
        jobCount: jobsStatus.length,
        failedJobs: jobsStatus.filter(j => j.status === "failed").length
      }
    });
  } catch (error) {
    return res.status(500).json({
      status: "error",
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

module.exports = router;
