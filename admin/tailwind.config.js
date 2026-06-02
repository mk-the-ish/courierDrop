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
        'orange-accent': '#FF6B35',
        'orange-light': '#FFA500',
        'dark-gradient-start': '#1a1a2e',
        'dark-gradient-end': '#16213e',
        'obsidian-deep': '#06030C',
        'cloud-white': '#F8F9FA',
        'transit-teal': '#008080',
        'active-mint': '#26A69A',
        'safe-slate': '#2F4F4F',
        'text-grey': '#9CA3AF',
        'border-dark': '#4B5563',
        // Heartbeat States
        'heartbeat-active': '#22c55e',
        'heartbeat-missed': '#FFA500',
        'heartbeat-alert': '#ef4444',
        // Legacy/fallback colors
        primary: '#FF6B35',
        secondary: '#2F4F4F',
        success: '#22c55e',
        warning: '#FFA500',
        error: '#ef4444',
        info: '#FF6B35',
      },
    },
  },
  plugins: [],
}
