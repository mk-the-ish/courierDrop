const NOTIFICATION_EVENT_TYPES = Object.freeze({
  COURIER_ASSIGNED: "courier.assigned",
  COURIER_ACCEPTED: "courier.accepted",
  COURIER_REASSIGNED: "courier.reassigned",
  HANDSHAKE_PIN_READY: "handshake.pin_ready",
  HANDSHAKE_PICKUP_COMPLETE: "handshake.pickup_complete",
  HANDSHAKE_DELIVERY_COMPLETE: "handshake.delivery_complete",
  TRACKING_DEVIATION_CRITICAL: "tracking.deviation_critical",
  SENDER_ETA_UPDATE: "tracking.sender_eta_update",
  RECIPIENT_DROPOFF_OTP_READY: "handshake.recipient_dropoff_otp",
  MANUAL_DROPOFF_OTP_SENT: "handshake.manual_dropoff_otp"
});

module.exports = {
  NOTIFICATION_EVENT_TYPES
};
