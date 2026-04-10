// DropCity Brand Theme Constants
// Based on the official brand guidelines in libmat/fonts.txt

export const brandColors = {
  // Transit Teal - Primary color for movement, efficiency, and modern tech feel
  transitTeal: '#008080',
  
  // Safe Slate - Deep, dark grey/green for contrast and security
  safeSlate: '#2F4F4F',
  
  // Alert Amber - Sparingly used for caution and readiness
  alertAmber: '#FFBF00',
  
  // Cloud White - Clean backgrounds for lightweight feel
  cloudWhite: '#F8F9FA',
};

export const heartbeatStates = {
  // Active Heartbeat - Green pulse
  active: '#22c55e',
  
  // Missed Frequency - Amber ripple
  missed: '#FFBF00',
  
  // Watchdog Alert - Red static
  alert: '#ef4444',
};

export const themeConfig = {
  primary: brandColors.transitTeal,
  secondary: brandColors.safeSlate,
  accent: brandColors.alertAmber,
  background: brandColors.cloudWhite,
  success: heartbeatStates.active,
  warning: heartbeatStates.missed,
  danger: heartbeatStates.alert,
};
