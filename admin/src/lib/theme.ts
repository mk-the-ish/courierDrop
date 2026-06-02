// DropCity Brand Theme Constants
// Shared palette for admin, courier, and client surfaces.

export const brandColors = {
  orangeAccent: '#FF6B35',
  orangeLight: '#FFA500',
  darkGradientStart: '#1a1a2e',
  darkGradientEnd: '#16213e',
  transitTeal: '#008080',
  activeMint: '#26A69A',
  safeSlate: '#2F4F4F',
  obsidianDeep: '#06030C',
  cloudWhite: '#F8F9FA',
  textGrey: '#9CA3AF',
  borderDark: '#4B5563',
};

export const heartbeatStates = {
  active: '#22c55e',
  missed: '#FFA500',
  alert: '#ef4444',
};

export const themeConfig = {
  primary: brandColors.orangeAccent,
  secondary: brandColors.safeSlate,
  accent: brandColors.orangeLight,
  background: brandColors.cloudWhite,
  success: heartbeatStates.active,
  warning: heartbeatStates.missed,
  danger: heartbeatStates.alert,
};
