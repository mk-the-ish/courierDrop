const { getSupabase } = require("../supabase");
const { sendAlert } = require("../services/alerting");

/**
 * Check system health and trigger alerts if thresholds exceeded
 */
async function checkAlerts() {
  const supabase = getSupabase();
  if (!supabase) {
    throw new Error("Supabase not configured - check SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env");
  }

  const results = {
    checked: 0,
    triggered: 0,
    errors: []
  };

  // Get all enabled alert rules
  const { data: rules, error: rulesError } = await supabase
    .from("alert_rules")
    .select("*")
    .eq("enabled", true);

  if (rulesError) {
    throw rulesError;
  }

  // Check each rule
  for (const rule of rules || []) {
    results.checked++;

    try {
      const shouldAlert = await evaluateRule(supabase, rule);

      if (shouldAlert) {
        // Check if we should send (don't spam the same alert)
        const recentAlert = await checkRecentAlert(supabase, rule.id);

        if (!recentAlert) {
          const alert = generateAlert(rule);
          const channels = (rule.notification_channels || "slack").split(",");
          const sendResult = await sendAlert(alert, channels);

          if (sendResult.success) {
            // Log the alert
            await supabase.from("alert_history").insert({
              rule_id: rule.id,
              triggered_at: new Date().toISOString(),
              status: "sent",
              message: alert.message,
              details: {
                result: sendResult.results
              }
            });

            results.triggered++;
          }
        }
      }
    } catch (error) {
      console.error(`[AlertJob] Rule ${rule.id} failed:`, error.message);
      results.errors.push({
        ruleId: rule.id,
        error: error.message
      });
    }
  }

  return results;
}

/**
 * Evaluate if an alert rule should trigger
 */
async function evaluateRule(supabase, rule) {
  const { type, threshold, time_window_minutes } = rule;

  switch (type) {
    case "error_spike":
      return checkErrorSpike(supabase, threshold, time_window_minutes);
    case "stuck_job":
      return checkStuckJob(supabase);
    case "high_failure_rate":
      return checkHighFailureRate(supabase, threshold, time_window_minutes);
    case "custom":
      // Placeholder for custom logic
      return false;
    default:
      return false;
  }
}

/**
 * Check for error spikes (errors > threshold in time window)
 */
async function checkErrorSpike(supabase, threshold, timeWindowMinutes) {
  const since = new Date();
  since.setMinutes(since.getMinutes() - timeWindowMinutes);

  const { count, error } = await supabase
    .from("error_logs")
    .select("id", { count: "exact" })
    .gte("occurred_at", since.toISOString());

  if (error) {
    throw error;
  }

  return count >= threshold;
}

/**
 * Check for stuck jobs (job not heartbeat in 2x expected frequency)
 */
async function checkStuckJob(supabase) {
  const { data: heartbeats, error } = await supabase
    .from("job_heartbeats")
    .select("*")
    .eq("status", "STUCK");

  if (error) {
    throw error;
  }

  return (heartbeats || []).length > 0;
}

/**
 * Check for high failure rate in scheduled jobs
 */
async function checkHighFailureRate(supabase, threshold, timeWindowMinutes) {
  const since = new Date();
  since.setMinutes(since.getMinutes() - timeWindowMinutes);

  // Get job execution stats for recent period
  const { data: jobs, error } = await supabase
    .from("job_heartbeats")
    .select("job_name,status")
    .gte("last_heartbeat_at", since.toISOString());

  if (error) {
    throw error;
  }

  if (!jobs || jobs.length === 0) {
    return false;
  }

  const stuck = jobs.filter((j) => j.status === "STUCK").length;
  const failureRate = stuck / jobs.length;

  return failureRate >= threshold / 100; // Threshold is percentage
}

/**
 * Check if similar alert was sent recently (don't spam)
 */
async function checkRecentAlert(supabase, ruleId) {
  const since = new Date();
  since.setHours(since.getHours() - 1); // Check last hour

  const { data, error } = await supabase
    .from("alert_history")
    .select("id")
    .eq("rule_id", ruleId)
    .eq("status", "sent")
    .gte("triggered_at", since.toISOString())
    .limit(1);

  if (error) {
    console.error("[AlertJob] Failed to check recent alert:", error.message);
    return false;
  }

  return data && data.length > 0;
}

/**
 * Generate alert object from rule
 */
function generateAlert(rule) {
  const alerts = {
    error_spike: {
      title: "Error Spike Detected",
      message: `High volume of errors detected. Threshold: ${rule.threshold} errors in ${rule.time_window_minutes} minutes.`,
      type: "error_spike"
    },
    stuck_job: {
      title: "Stuck Background Job",
      message: "One or more scheduled jobs are not responding. Check system health immediately.",
      type: "stuck_job"
    },
    high_failure_rate: {
      title: "High Job Failure Rate",
      message: `Job failure rate exceeded ${rule.threshold}%. Check recent job executions.`,
      type: "high_failure_rate"
    }
  };

  const base = alerts[rule.type] || {
    title: "System Alert",
    message: "Alert condition triggered",
    type: rule.type
  };

  return {
    ...base,
    severity: rule.severity || "warning",
    details: {
      ruleId: rule.id,
      threshold: rule.threshold,
      type: rule.type
    }
  };
}

// Run if executed directly
if (require.main === module) {
  checkAlerts()
    .then((result) => {
      console.log(
        `Alert check complete. Checked: ${result.checked}, Triggered: ${result.triggered}`
      );
      if (result.errors.length > 0) {
        console.error("Errors:", result.errors);
      }
      process.exit(0);
    })
    .catch((error) => {
      console.error("Alert check failed:", error);
      process.exit(1);
    });
}

module.exports = {
  checkAlerts,
  evaluateRule,
  checkErrorSpike,
  checkStuckJob,
  checkHighFailureRate
};
