/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // DropCity Brand Colors
        'transit-teal': '#008080',
        'safe-slate': '#2F4F4F',
        'alert-amber': '#FFBF00',
        'cloud-white': '#F8F9FA',
        // Heartbeat States
        'heartbeat-active': '#22c55e',
        'heartbeat-missed': '#FFBF00',
        'heartbeat-alert': '#ef4444',
        // Legacy/fallback colors
        primary: '#008080',
        secondary: '#2F4F4F',
        success: '#22c55e',
        warning: '#FFBF00',
        error: '#ef4444',
        info: '#008080',
      },
    },
  },
  plugins: [],
}
