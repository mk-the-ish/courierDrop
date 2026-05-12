/**
 * SMS Queue Processing Job
 * Scheduled job that processes pending SMS every 5 minutes
 * Handles retry logic and offline queue management
 */

const cron = require('node-cron');
const { processPendingSms } = require('../services/notification_service');

let isProcessing = false;

/**
 * Initialize SMS queue processor job
 * Runs every 5 minutes
 */
async function initSmsQueueJob() {
  // Schedule to run every 5 minutes
  const job = cron.schedule('*/5 * * * *', async () => {
    if (isProcessing) {
      console.log('[SMSQueue] Job already running, skipping...');
      return;
    }

    isProcessing = true;
    const startTime = Date.now();

    try {
      console.log('[SMSQueue] Starting queue processing...');
      const result = await processPendingSms(50); // Process up to 50 at a time

      const duration = ((Date.now() - startTime) / 1000).toFixed(2);
      console.log(
        `[SMSQueue] Completed in ${duration}s - ` +
        `Processed: ${result.processed}, ` +
        `Succeeded: ${result.succeeded}, ` +
        `Failed: ${result.failed}`
      );

      // Log metrics
      if (result.failed > 0) {
        console.warn(`[SMSQueue] ${result.failed} SMS failed to send (will retry)`);
      }
    } catch (error) {
      console.error('[SMSQueue] Job failed:', error.message);
    } finally {
      isProcessing = false;
    }
  });

  console.log('[SMSQueue] Job initialized - runs every 5 minutes');
  return job;
}

/**
 * Manually trigger SMS queue processing (for testing or immediate needs)
 */
async function triggerSmsQueueProcessing(limit = 50) {
  if (isProcessing) {
    throw new Error('SMS queue processing already in progress');
  }

  isProcessing = true;

  try {
    const result = await processPendingSms(limit);
    return {
      success: true,
      ...result,
    };
  } finally {
    isProcessing = false;
  }
}

/**
 * Get SMS queue status
 */
async function getSmsQueueStatus() {
  const { getSupabase } = require('../supabase');
  const supabase = getSupabase();

  try {
    const { data: pending, error: pendingError } = await supabase
      .from('sms_queue')
      .select('id')
      .eq('delivery_status', 'pending')
      .limit(1000);

    const { data: failed, error: failedError } = await supabase
      .from('sms_queue')
      .select('id')
      .eq('delivery_status', 'failed')
      .limit(1000);

    const { data: sent, error: sentError } = await supabase
      .from('sms_queue')
      .select('id')
      .eq('delivery_status', 'sent')
      .limit(1000);

    const { data: abandoned, error: abandonedError } = await supabase
      .from('sms_queue')
      .select('id')
      .eq('delivery_status', 'abandoned')
      .limit(1000);

    if (pendingError || failedError || sentError || abandonedError) {
      throw new Error('Failed to fetch queue status');
    }

    return {
      pending: pending?.length || 0,
      failed: failed?.length || 0,
      sent: sent?.length || 0,
      abandoned: abandoned?.length || 0,
      isProcessing,
    };
  } catch (error) {
    console.error('[SMSQueue] Failed to get status:', error);
    throw error;
  }
}

module.exports = {
  initSmsQueueJob,
  triggerSmsQueueProcessing,
  getSmsQueueStatus,
};
