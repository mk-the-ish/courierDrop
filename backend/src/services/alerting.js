/**
 * Alert Notification Service
 * Handles SMS, Email, and Slack notifications for system alerts
 */

const config = require("../config");

// Slack notification sender
async function sendSlackAlert(webhookUrl, alert) {
  if (!webhookUrl) {
    console.warn("[Alerting] Slack webhook URL not configured");
    return { success: false, error: "Webhook URL not configured" };
  }

  try {
    const color = alert.severity === "critical" ? "danger" : "warning";
    const message = {
      attachments: [
        {
          color,
          title: `🚨 ${alert.title}`,
          text: alert.message,
          fields: [
            {
              title: "Severity",
              value: alert.severity.toUpperCase(),
              short: true
            },
            {
              title: "Alert Type",
              value: alert.type,
              short: true
            },
            {
              title: "Time",
              value: new Date().toISOString(),
              short: true
            },
            {
              title: "Details",
              value: JSON.stringify(alert.details || {}),
              short: false
            }
          ],
          footer: "DropCity Alert System"
        }
      ]
    };

    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(message)
    });

    if (!response.ok) {
      throw new Error(`Slack API error: ${response.status}`);
    }

    console.log(`[Alerting] Slack notification sent: ${alert.title}`);
    return { success: true };
  } catch (error) {
    console.error("[Alerting] Slack notification failed:", error.message);
    return { success: false, error: error.message };
  }
}

// Email notification sender
async function sendEmailAlert(emailConfig, alert) {
  if (!emailConfig || !emailConfig.to) {
    console.warn("[Alerting] Email configuration not complete");
    return { success: false, error: "Email config missing" };
  }

  try {
    // Using Supabase built-in email or SendGrid via environment variable
    const provider = emailConfig.provider || "supabase";

    if (provider === "supabase") {
      // Placeholder for Supabase email integration
      // In production, use Supabase's built-in email service
      console.log(`[Alerting] Email would be sent via Supabase to: ${emailConfig.to}`);
    } else if (provider === "sendgrid") {
      // Placeholder for SendGrid integration
      const sendgridKey = process.env.SENDGRID_API_KEY;
      if (!sendgridKey) {
        throw new Error("SENDGRID_API_KEY not configured");
      }
      console.log(`[Alerting] Email would be sent via SendGrid to: ${emailConfig.to}`);
    }

    const htmlBody = generateEmailHTML(alert);

    console.log(
      `[Alerting] Email notification generated for ${emailConfig.to}: ${alert.title}`
    );
    return { success: true, provider };
  } catch (error) {
    console.error("[Alerting] Email notification failed:", error.message);
    return { success: false, error: error.message };
  }
}

// SMS notification sender
async function sendSmsAlert(smsConfig, alert) {
  if (!smsConfig || !smsConfig.phoneNumber) {
    console.warn("[Alerting] SMS configuration not complete");
    return { success: false, error: "SMS config missing" };
  }

  try {
    // Placeholder for Twilio integration
    const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID;
    const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
    const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER;

    if (!twilioAccountSid || !twilioAuthToken) {
      throw new Error("Twilio credentials not configured");
    }

    const message = `[${alert.severity.toUpperCase()}] ${alert.title}: ${alert.message}`;

    // In production, actually send via Twilio
    console.log(
      `[Alerting] SMS would be sent to ${smsConfig.phoneNumber}: ${message}`
    );

    return { success: true, provider: "twilio" };
  } catch (error) {
    console.error("[Alerting] SMS notification failed:", error.message);
    return { success: false, error: error.message };
  }
}

// Generate HTML email body
function generateEmailHTML(alert) {
  const timestamp = new Date().toISOString();
  const severityColor = alert.severity === "critical" ? "#dc2626" : "#f59e0b";

  return `
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <style>
          body { font-family: sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: ${severityColor}; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
          .content { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; }
          .footer { background: #f3f4f6; padding: 15px; border-radius: 0 0 8px 8px; font-size: 12px; color: #666; }
          .detail { margin: 12px 0; }
          .detail-label { font-weight: bold; }
          code { background: #f0f0f0; padding: 2px 6px; border-radius: 4px; font-family: monospace; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h2>🚨 ${alert.title}</h2>
          </div>
          <div class="content">
            <p>${alert.message}</p>
            
            <div class="detail">
              <span class="detail-label">Severity:</span> ${alert.severity.toUpperCase()}
            </div>
            
            <div class="detail">
              <span class="detail-label">Alert Type:</span> ${alert.type}
            </div>
            
            <div class="detail">
              <span class="detail-label">Time:</span> ${timestamp}
            </div>
            
            ${
              alert.details
                ? `
            <div class="detail">
              <span class="detail-label">Details:</span><br>
              <code>${JSON.stringify(alert.details, null, 2)}</code>
            </div>
            `
                : ""
            }
          </div>
          <div class="footer">
            <p>This is an automated alert from DropCity. Please do not reply to this email.</p>
          </div>
        </div>
      </body>
    </html>
  `;
}

// Main alert sender function
async function sendAlert(alert, channels = []) {
  if (!alert || !alert.type) {
    console.warn("[Alerting] Invalid alert object");
    return { success: false, error: "Invalid alert" };
  }

  const results = {};

  // Log the alert
  console.log(
    `[Alerting] Sending ${alert.severity} alert: ${alert.title} via [${channels.join(", ")}]`
  );

  // Send to each configured channel
  if (channels.includes("slack")) {
    results.slack = await sendSlackAlert(
      process.env.SLACK_WEBHOOK_URL,
      alert
    );
  }

  if (channels.includes("email")) {
    results.email = await sendEmailAlert(
      {
        to: process.env.ALERT_EMAIL,
        provider: process.env.EMAIL_PROVIDER || "supabase"
      },
      alert
    );
  }

  if (channels.includes("sms")) {
    results.sms = await sendSmsAlert(
      {
        phoneNumber: process.env.ALERT_PHONE_NUMBER
      },
      alert
    );
  }

  const success = Object.values(results).some((r) => r.success);

  return {
    success,
    results,
    alert: { type: alert.type, severity: alert.severity, timestamp: new Date().toISOString() }
  };
}

module.exports = {
  sendAlert,
  sendSlackAlert,
  sendEmailAlert,
  sendSmsAlert,
  generateEmailHTML
};
