const config = require("../config");

/**
 * Send SMS via Twilio REST API (optional). Returns { ok, skipped, error }.
 */
async function sendSmsE164(toE164, body) {
  const sid = config.twilioAccountSid;
  const token = config.twilioAuthToken;
  const from = config.twilioFromNumber;
  if (!sid || !token || !from) {
    return { ok: false, skipped: true };
  }
  const auth = Buffer.from(`${sid}:${token}`).toString("base64");
  const params = new URLSearchParams({ To: toE164, From: from, Body: body });
  const url = `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: params.toString()
  });
  if (!res.ok) {
    const text = await res.text();
    return { ok: false, skipped: false, error: text };
  }
  return { ok: true, skipped: false };
}

module.exports = {
  sendSmsE164
};
