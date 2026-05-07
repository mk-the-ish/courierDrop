const { processOutboxBatch } = require("../services/notification_service");

async function runNotificationOutboxJob() {
  const result = await processOutboxBatch(100);
  if (result.processed > 0) {
    console.log(
      `[NotificationOutbox] processed=${result.processed} success=${result.success} failed=${result.failed}`
    );
  }
  return result;
}

module.exports = {
  runNotificationOutboxJob
};
