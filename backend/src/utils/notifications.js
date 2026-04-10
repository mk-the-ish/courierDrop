const { getFirebaseMessaging } = require("../firebase");
const { getSupabase } = require("../supabase");

function normalizeData(data) {
  const output = {};
  Object.entries(data || {}).forEach(([key, value]) => {
    output[key] = value == null ? "" : String(value);
  });
  return output;
}

async function sendToUser(userId, title, body, data = {}) {
  const messaging = getFirebaseMessaging();
  if (!messaging) {
    return;
  }
  const supabase = getSupabase();
  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", userId);

  if (!tokens || tokens.length === 0) {
    return;
  }
  const registrationTokens = tokens.map((t) => t.token);
  await messaging.sendEachForMulticast({
    tokens: registrationTokens,
    notification: { title, body },
    data: normalizeData(data)
  });
}

async function sendToTopic(topic, title, body, data = {}) {
  const messaging = getFirebaseMessaging();
  if (!messaging) {
    return;
  }
  await messaging.send({
    topic,
    notification: { title, body },
    data: normalizeData(data)
  });
}

function parcelTopic(parcelId) {
  return `parcel_${parcelId}`;
}

async function sendToParcelTopic(parcelId, title, body, data = {}) {
  if (!parcelId) {
    return;
  }
  return sendToTopic(parcelTopic(parcelId), title, body, data);
}

module.exports = {
  sendToUser,
  sendToTopic,
  sendToParcelTopic,
  parcelTopic
};
