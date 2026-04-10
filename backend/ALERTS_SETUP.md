# Alert System Setup Guide

## Overview
The DropCity alert system monitors system health and sends notifications when issues occur:
- **Error Spikes**: Detects unusual increases in application errors
- **Stuck Jobs**: Monitors background job health via heartbeats
- **High Failure Rates**: Alerts when jobs have too many failures

## Features
- Multi-channel notifications: Slack, Email, SMS
- Configurable alert rules via admin dashboard
- Alert history and deduplication (no duplicate alerts within 1 hour)
- Rule-based evaluation every 2 minutes
- Integration with error tracking and job scheduling systems

## Quick Start

### 1. Configure Environment Variables

Add the following to your `.env` file in the `backend/` directory:

```bash
# Slack Notifications
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Email Notifications
ALERT_EMAIL=alerts@dropcity.io
EMAIL_PROVIDER=sendgrid  # or 'supabase'
SENDGRID_API_KEY=SG.your-api-key

# SMS Notifications (Twilio)
TWILIO_ACCOUNT_SID=your-account-sid
TWILIO_AUTH_TOKEN=your-auth-token
TWILIO_PHONE_NUMBER=+1234567890
ALERT_PHONE_NUMBER=+0987654321  # Recipient phone number
```

### 2. Database Initialization

The alert system requires the `alert_rules` and `alert_history` tables. Run the migration:

```bash
cd backend
psql -U postgres -d dropcity -f sql/007_alerts.sql
```

This creates:
- `alert_rules` table with default rules (error spike, stuck job, high failure rate)
- `alert_history` table for tracking triggered alerts

### 3. Start the Backend

The scheduler starts automatically with the backend:

```bash
cd backend
npm start
```

You should see:
```
[Scheduler] Started job: heartbeat_watchdog
[Scheduler] Started job: check_alerts
```

The `check_alerts` job runs every 2 minutes.

## Using the Admin Dashboard

### Access Alerts Page
1. Go to the admin dashboard: `http://localhost:3000/admin`
2. Click the **Alerts** navigation button
3. Enter your backend URL and admin token

### View Alert Rules
The default rules are:
- **Error Spike**: Alert if 50+ errors in 30 minutes
- **Stuck Job**: Alert if job heartbeat is missing (STUCK status)
- **High Failure Rate**: Alert if >25% of jobs fail in 60 minutes

### Create New Alert Rule
1. Click **+ New Alert Rule**
2. Fill in the form:
   - **Type**: error_spike, stuck_job, or high_failure_rate
   - **Name**: Human-readable name for the alert
   - **Threshold**: Numeric value for triggering (50 errors, 25%, etc.)
   - **Time Window**: Minutes to evaluate (30, 60, etc.)
   - **Severity**: info, warning, or critical
   - **Channels**: Select Slack, Email, and/or SMS
3. Click **Create Alert Rule**

### Manage Rules
- **Toggle**: Enable/disable rules without deleting
- **Delete**: Remove rules permanently
- **View History**: Switch to History tab to see all triggered alerts

## How It Works

### Alert Evaluation Process

Every 2 minutes, the `check_alerts` job:

1. Fetches all enabled alert rules from the database
2. For each rule, evaluates the condition:
   - **Error Spike**: Counts errors in the last N minutes
   - **Stuck Job**: Checks for jobs with status='STUCK'
   - **High Failure Rate**: Calculates failure percentage
3. Checks for recent alerts (deduplication):
   - Only sends if last alert for this rule was >1 hour ago
4. Sends notifications to configured channels
5. Logs the alert event to `alert_history` table

### Notification Flow

```
check_alerts job
    ↓
evaluate alert_rules
    ↓
check recent alerts (dedup)
    ↓
sendAlert() → alerting service
    ├─ sendSlackAlert() → Slack webhook
    ├─ sendEmailAlert() → SendGrid/Supabase
    └─ sendSmsAlert() → Twilio API
    ↓
log to alert_history table
```

## API Endpoints

All endpoints require admin role and Bearer token authentication.

### GET /admin/alerts/rules
Fetch all alert rules
```bash
curl -H "Authorization: Bearer {token}" \
  http://localhost:8080/admin/alerts/rules
```

### POST /admin/alerts/rules
Create a new alert rule
```bash
curl -X POST -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "error_spike",
    "name": "Critical Error Alert",
    "threshold": 100,
    "time_window_minutes": 30,
    "severity": "critical",
    "notification_channels": ["slack", "email"]
  }' \
  http://localhost:8080/admin/alerts/rules
```

### PATCH /admin/alerts/rules/{id}
Update an alert rule
```bash
curl -X PATCH -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false, "threshold": 75}' \
  http://localhost:8080/admin/alerts/rules/1
```

### DELETE /admin/alerts/rules/{id}
Delete an alert rule
```bash
curl -X DELETE -H "Authorization: Bearer {token}" \
  http://localhost:8080/admin/alerts/rules/1
```

### GET /admin/alerts/history
Fetch alert history
```bash
curl -H "Authorization: Bearer {token}" \
  'http://localhost:8080/admin/alerts/history?limit=50&rule_id=1'
```

## Configuration Files

### Database Schema (`backend/sql/007_alerts.sql`)
Creates the alert infrastructure:
- `alert_rules` table: Stores alert configuration
- `alert_history` table: Logs all triggered alerts

### Alert Service (`backend/src/services/alerting.js`)
Handles notifications:
- `sendAlert()`: Main dispatcher
- `sendSlackAlert()`: Posts to Slack webhook
- `sendEmailAlert()`: Sends HTML email
- `sendSmsAlert()`: Sends SMS via Twilio

### Alert Job (`backend/src/jobs/check_alerts.js`)
Evaluates conditions:
- `checkAlerts()`: Main job function
- `evaluateRule()`: Dispatcher for different alert types
- `checkErrorSpike()`: Detects error spikes
- `checkStuckJob()`: Monitors job health
- `checkHighFailureRate()`: Calculates failure rates

### Scheduler Service (`backend/src/services/scheduler.js`)
Manages background jobs:
- `JobScheduler` class: Job registration and execution
- `initializeDefaultJobs()`: Registers heartbeat_watchdog and check_alerts
- Health endpoint: `GET /health/jobs` for job status

## Testing

### Manual Test Alert
1. Create a test rule with low threshold
2. Wait for next evaluation cycle (max 2 minutes)
3. Check Slack/email for notification
4. Verify entry in Alert History

### Test Slack Integration
```bash
# Send test message directly
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "Test alert from DropCity"
  }'
```

### Monitor Alert Execution
```bash
# Check scheduler status
curl -H "Authorization: Bearer {token}" \
  http://localhost:8080/health/jobs

# Look for check_alerts job:
# - status: "RUNNING"
# - lastRun: recent timestamp
# - nextRun: within 2 minutes
```

## Troubleshooting

### Alerts Not Sending

**Check 1: Job Execution**
```bash
curl -H "Authorization: Bearer {token}" \
  http://localhost:8080/health/jobs | grep -A 10 check_alerts
```
- Verify `status` is "RUNNING"
- Check `lastRun` is recent
- If `failureCount` is high, check logs

**Check 2: Alert Rules**
```bash
curl -H "Authorization: Bearer {token}" \
  http://localhost:8080/admin/alerts/rules
```
- Verify rules have `enabled: true`
- Verify `notification_channels` include desired channel

**Check 3: Environment Variables**
```bash
# Verify in backend/.env
echo $SLACK_WEBHOOK_URL
echo $SENDGRID_API_KEY
echo $TWILIO_ACCOUNT_SID
```

**Check 4: Backend Logs**
```bash
cd backend
npm start 2>&1 | grep -i alert
```

### Deduplication Too Aggressive
Alert system prevents sending the same alert more than once per hour.
- To test multiple alerts, wait >1 hour or create separate rules
- Adjust deduplication window in `src/jobs/check_alerts.js` line ~50

### Email Not Sending
- Verify `EMAIL_PROVIDER` is set correctly
- If using SendGrid, verify API key is valid
- If using Supabase, verify email configuration in Supabase dashboard

### SMS Not Sending
- Verify Twilio credentials (account SID, auth token)
- Verify phone numbers are in E.164 format (+1234567890)
- Check Twilio console for API errors

## Database Schema

### alert_rules Table
```sql
CREATE TABLE alert_rules (
  id SERIAL PRIMARY KEY,
  type TEXT NOT NULL,              -- 'error_spike', 'stuck_job', 'high_failure_rate'
  name TEXT NOT NULL,
  threshold INT NOT NULL,          -- Alert trigger value
  time_window_minutes INT DEFAULT 30,
  severity TEXT DEFAULT 'warning',  -- 'info', 'warning', 'critical'
  notification_channels TEXT[] DEFAULT '{}',
  enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### alert_history Table
```sql
CREATE TABLE alert_history (
  id SERIAL PRIMARY KEY,
  rule_id INT REFERENCES alert_rules(id),
  triggered_at TIMESTAMP DEFAULT NOW(),
  status TEXT,                     -- 'sent', 'failed', 'queued'
  message TEXT,
  details JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## Advanced Configuration

### Disable Alert Deduplication
Edit `backend/src/jobs/check_alerts.js`, comment out the deduplication check:
```javascript
// Skip deduplication check for testing
// const recentAlert = await checkRecentAlert(rule.id);
// if (recentAlert) {
//   console.log(`[Alerts] Skipping ${rule.id} (recent alert exists)`);
//   continue;
// }
```

### Change Alert Frequency
Edit `backend/src/services/scheduler.js`, line ~95:
```javascript
// Change from "*/2 * * * *" (every 2 minutes) to desired frequency
scheduler.registerJob("check_alerts", "*/10 * * * *", checkAlerts);
```

### Add Custom Alert Type
1. Add new case in `evaluateRule()` in `check_alerts.js`
2. Create function to check condition
3. Add rule type option in admin UI (`pages/alerts.js`)

## Production Considerations

- **Rate Limiting**: Implement rate limiting on alert channels to prevent spam
- **Backup Notifications**: Use multiple channels for critical alerts
- **Alert Escalation**: Create higher-severity alerts that trigger after repeated failures
- **Audit Trail**: All alerts logged to `alert_history` for compliance
- **Monitoring**: Monitor the scheduler health endpoint for job failures
