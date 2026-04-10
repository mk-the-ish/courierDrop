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

module.exports = router;
