const { getSupabase } = require("../supabase");

async function runHeartbeatWatchdog() {
  const supabase = getSupabase();
  if (!supabase) {
    throw new Error("Supabase not configured - check SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env");
  }
  
  const { data, error } = await supabase
    .from("job_heartbeats")
    .select("job_name,last_heartbeat_at,expected_frequency_sec,status");
  if (error) {
    throw error;
  }

  const now = Date.now();
  const stuckJobs = [];

  for (const job of data || []) {
    const expected = Number(job.expected_frequency_sec || 0);
    if (!expected || !job.last_heartbeat_at) {
      continue;
    }
    const last = new Date(job.last_heartbeat_at).getTime();
    const thresholdMs = expected * 2 * 1000;
    if (now - last > thresholdMs && job.status !== "STUCK") {
      stuckJobs.push(job.job_name);
    }
  }

  if (stuckJobs.length > 0) {
    const { error: updateError } = await supabase
      .from("job_heartbeats")
      .update({
        status: "STUCK",
        last_status_change_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .in("job_name", stuckJobs);
    if (updateError) {
      throw updateError;
    }
  }

  return { stuckJobs, checked: data?.length || 0 };
}

if (require.main === module) {
  runHeartbeatWatchdog()
    .then((result) => {
      // eslint-disable-next-line no-console
      console.log(`Watchdog complete. Checked ${result.checked}. Stuck: ${result.stuckJobs.length}`);
      process.exit(0);
    })
    .catch((error) => {
      // eslint-disable-next-line no-console
      console.error("Watchdog failed", error);
      process.exit(1);
    });
}

module.exports = {
  runHeartbeatWatchdog
};
