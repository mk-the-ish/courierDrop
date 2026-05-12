/**
 * Notification recipients for a parcel (sender + optional recipient when dual_tracking).
 */
function stakeholderUserIds(parcel) {
  const ids = new Set();
  if (parcel?.created_by) {
    ids.add(parcel.created_by);
  }
  if (parcel?.dual_tracking && parcel?.recipient_id) {
    ids.add(parcel.recipient_id);
  }
  return Array.from(ids);
}

/** Sender + recipient (when dual_tracking); use for client-facing parcel updates. */
function parcelClientRecipients(parcel) {
  return stakeholderUserIds(parcel);
}

module.exports = {
  stakeholderUserIds,
  parcelClientRecipients
};
