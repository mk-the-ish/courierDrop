const cron = require("node-cron");
const { runHeartbeatWatchdog } = require("../jobs/heartbeat_watchdog");
const { checkAlerts } = require("../jobs/check_alerts");
const { matchPendingParcels } = require("./matching");
const { validateTrackingHealth } = require("../jobs/tracking_validation");
const { cleanupTrackingData } = require("../jobs/cleanup_tracking_data");

class JobScheduler {
  constructor() {
    this.jobs = new Map();
    this.running = false;
  }

  /**
   * Register a scheduled job
   * @param {string} jobName - Unique job identifier
   * @param {string} cronExpression - Cron expression 
   * @param {Function} jobFn - Async function to execute
   * @param {Object} options - Additional options
   */
  registerJob(jobName, cronExpression, jobFn, options = {}) {
    if (this.jobs.has(jobName)) {
      console.warn(`Job ${jobName} already registered, replacing...`);
      this.stopJob(jobName);
    }

    const jobData = {
      name: jobName,
      cronExpression,
      jobFn,
      lastRun: null,
      nextRun: null,
      status: "REGISTERED",
      errors: [],
      successCount: 0,
      failureCount: 0,
      ...options
    };

    this.jobs.set(jobName, jobData);
    console.log(`[Scheduler] Registered job: ${jobName} with cron "${cronExpression}"`);
    return jobData;
  }

  /**
   * Start all registered jobs
   */
  startAll() {
    if (this.running) {
      console.warn("[Scheduler] Already running");
      return;
    }

    console.log("[Scheduler] Starting scheduler...");
    this.running = true;

    for (const [jobName, jobData] of this.jobs.entries()) {
      try {
        // Validate cron expression
        if (!cron.validate(jobData.cronExpression)) {
          throw new Error(`Invalid cron expression: ${jobData.cronExpression}`);
        }

        // Schedule the job
        const task = cron.schedule(jobData.cronExpression, async () => {
          await this._executeJob(jobName);
        });

        jobData.task = task;
        jobData.status = "RUNNING";

        // Calculate next run
        this._updateNextRun(jobName);

        console.log(`[Scheduler] Started job: ${jobName}`);
      } catch (error) {
        jobData.status = "ERROR";
        jobData.errors.push({
          timestamp: new Date().toISOString(),
          error: error.message
        });
        console.error(`[Scheduler] Failed to start job ${jobName}:`, error.message);
      }
    }
  }

  /**
   * Stop all registered jobs
   */
  stopAll() {
    console.log("[Scheduler] Stopping scheduler...");
    for (const [jobName] of this.jobs.entries()) {
      this.stopJob(jobName);
    }
    this.running = false;
  }

  /**
   * Stop a specific job
   */
  stopJob(jobName) {
    const jobData = this.jobs.get(jobName);
    if (!jobData) {
      console.warn(`Job ${jobName} not found`);
      return;
    }

    if (jobData.task) {
      jobData.task.stop();
      jobData.task.destroy();
    }
    jobData.status = "STOPPED";
    console.log(`[Scheduler] Stopped job: ${jobName}`);
  }

  /**
   * Execute a job (internal)
   */
  async _executeJob(jobName) {
    const jobData = this.jobs.get(jobName);
    if (!jobData) return;

    const startTime = Date.now();
    jobData.lastRun = new Date().toISOString();

    try {
      await jobData.jobFn();
      jobData.successCount++;
      jobData.status = "RUNNING";
      const duration = Date.now() - startTime;
      console.log(`[Scheduler] ✓ ${jobName} completed in ${duration}ms`);
    } catch (error) {
      jobData.failureCount++;
      jobData.status = "ERROR";
      jobData.errors.push({
        timestamp: new Date().toISOString(),
        error: error.message,
        stack: error.stack
      });
      // Keep only last 10 errors
      if (jobData.errors.length > 10) {
        jobData.errors.shift();
      }
      console.error(`[Scheduler] ✗ ${jobName} failed:`, error.message);
    }

    this._updateNextRun(jobName);
  }

  /**
   * Calculate next run time for a job
   */
  _updateNextRun(jobName) {
    const jobData = this.jobs.get(jobName);
    if (!jobData || !jobData.task) return;

    try {
      // Get next execution time - node-cron provides nextDate as a method or property
      let nextDate;
      if (typeof jobData.task.nextDate === 'function') {
        nextDate = jobData.task.nextDate();
      } else if (jobData.task.nextDate) {
        nextDate = jobData.task.nextDate;
      }
      jobData.nextRun = nextDate ? new Date(nextDate).toISOString() : null;
    } catch (error) {
      // Silently ignore - nextDate calculation is non-critical
      jobData.nextRun = null;
    }
  }

  /**
   * Get job status by name
   */
  getJobStatus(jobName) {
    const jobData = this.jobs.get(jobName);
    if (!jobData) return null;

    return {
      name: jobData.name,
      status: jobData.status,
      lastRun: jobData.lastRun,
      nextRun: jobData.nextRun,
      successCount: jobData.successCount,
      failureCount: jobData.failureCount,
      cronExpression: jobData.cronExpression,
      recentErrors: jobData.errors.slice(-3) // Last 3 errors
    };
  }

  /**
   * Get all jobs status
   */
  getAllJobsStatus() {
    const status = [];
    for (const [jobName] of this.jobs.entries()) {
      status.push(this.getJobStatus(jobName));
    }
    return status;
  }

  /**
   * Check if scheduler is running
   */
  isRunning() {
    return this.running;
  }
}

// Singleton instance
let schedulerInstance = null;

function getScheduler() {
  if (!schedulerInstance) {
    schedulerInstance = new JobScheduler();
  }
  return schedulerInstance;
}

/**
 * Initialize default jobs
 */
function initializeDefaultJobs() {
  const scheduler = getScheduler();

  // Heartbeat watchdog: runs every 5 minutes
  scheduler.registerJob(
    "heartbeat_watchdog",
    "*/5 * * * *", // Every 5 minutes
    runHeartbeatWatchdog,
    {
      description: "Monitors job heartbeats and marks stuck jobs"
    }
  );

  // Alert checker: runs every 2 minutes
  scheduler.registerJob(
    "check_alerts",
    "*/2 * * * *", // Every 2 minutes
    checkAlerts,
    {
      description: "Evaluates alert rules and sends notifications"
    }
  );

  // Parcel matching: runs every 3 minutes
  scheduler.registerJob(
    "match_parcels",
    "*/3 * * * *", // Every 3 minutes
    matchPendingParcels,
    {
      description: "Matches pending parcels with available corridors"
    }
  );

  // Tracking validation: runs every 2 minutes
  scheduler.registerJob(
    "validate_tracking",
    "*/2 * * * *", // Every 2 minutes
    validateTrackingHealth,
    {
      description: "Validates courier tracking and detects route deviations"
    }
  );

  // Tracking retention cleanup: runs daily at 02:00
  scheduler.registerJob(
    "cleanup_tracking_data",
    "0 2 * * *",
    cleanupTrackingData,
    {
      description: "Cleans up old tracking logs and deviation events per privacy policy"
    }
  );
}

module.exports = {
  getScheduler,
  initializeDefaultJobs,
  JobScheduler
};
