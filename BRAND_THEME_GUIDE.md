# DropCity Brand & Theme Guide

## Overview
This document outlines the DropCity brand identity and design system implemented across all three platforms: Admin Dashboard, Courier App, and Client App.

## Brand Colors

### Primary Colors

#### Transit Teal `#008080`
- **Purpose**: Primary brand color representing movement, efficiency, and modern tech feel
- **Usage**: Main UI elements, buttons, sidebars, active states
- **Psychology**: Conveys trust, technology, and forward motion
- **Applications**: Navigation, CTAs, interactive elements

#### Safe Slate `#2F4F4F`
- **Purpose**: Deep, dark grey/green providing contrast and security
- **Usage**: Text, secondary elements, backgrounds, dark mode accents
- **Psychology**: Grounded, secure, professional
- **Applications**: Headings, sidebar text, borders

#### Alert Amber `#FFBF00`
- **Purpose**: Caution color used sparingly for notifications and alerts
- **Usage**: Alerts, warnings, virtual stop markers, amber heartbeat states
- **Psychology**: Draws attention, indicates readiness/caution
- **Applications**: Warning badges, missed frequency indicators

#### Cloud White `#F8F9FA`
- **Purpose**: Clean background color for lightweight feel
- **Usage**: Primary backgrounds, card backgrounds, clean spaces
- **Psychology**: Minimal, clean, spacious
- **Applications**: Main backgrounds, card surfaces, UI containers

## Heartbeat Visualization States

### Green Pulse - Active Heartbeat `#22c55e`
- **State**: System running normally
- **Visual**: Animated pulse/glow effect
- **Meaning**: All systems operational
- **Component**: HeartbeatItem with 'active' state

### Amber Ripple - Missed Frequency `#FFBF00`
- **State**: Missed heartbeat or delayed response
- **Visual**: Ripple effect with amber color
- **Meaning**: Caution - potential issues
- **Component**: HeartbeatItem with 'missed' state

### Red Static - Watchdog Alert `#ef4444`
- **State**: Critical alert or failure
- **Visual**: Static/pulsing alert state
- **Meaning**: Immediate attention required
- **Component**: HeartbeatItem with 'alert' state

## Custom Components

### HandshakeIcon
A custom SVG icon representing the three-way handshake for connection visualization.
- **Location**: `admin/src/components/HandshakeIcon.js`
- **Usage**: Display during three-way handshake operations
- **Props**:
  - `size`: Icon size in pixels (default: 24)
  - `active`: Boolean for active/inactive state
  - `className`: Additional CSS classes

### HeartbeatVisualization
Complete heartbeat visualization component showing system health states.
- **Location**: `admin/src/components/HeartbeatVisualization.js`
- **Exports**: Default component and HeartbeatItem
- **Usage**: Dashboard system health monitoring
- **Props**:
  - `items`: Array of heartbeat item configurations
  - `title`: Section title (default: 'System Heartbeat')

## Tailwind Configuration

All applications include brand colors in their Tailwind config:

```javascript
'transit-teal': '#008080',
'safe-slate': '#2F4F4F',
'alert-amber': '#FFBF00',
'cloud-white': '#F8F9FA',
'heartbeat-active': '#22c55e',
'heartbeat-missed': '#FFBF00',
'heartbeat-alert': '#ef4444',
```

## CSS Variables

Global CSS variables are defined in `globals.css` for both light and dark modes:

```css
--primary: 0 128 128; /* Transit Teal */
--secondary: 47 79 79; /* Safe Slate */
--accent: 255 191 0; /* Alert Amber */
--background: 248 249 250; /* Cloud White */
```

## Theme Files

Each application includes a `theme.ts` file exporting:
- `brandColors`: Object with all brand color values
- `heartbeatStates`: Object with heartbeat state colors
- `themeConfig`: Consolidated theme configuration

### Locations
- Admin: `admin/src/lib/theme.ts`
- Ops: `ops/src/lib/theme.ts`
- Courier: `courier/lib/theme.ts`
- Client: `client/lib/theme.ts`

## Implementation Guidelines

### For Buttons
```jsx
<button className="btn-primary">Call to Action</button>
```
Uses Transit Teal primary color with hover state to Safe Slate.

### For Cards
```jsx
<div className="card p-6">Content</div>
```
Uses Cloud White background with subtle shadow.

### For Status Indicators
```jsx
<div className="badge-warning">Warning</div>
```
Uses Alert Amber for warnings, green for success, red for errors.

### For Heartbeat Display
```jsx
import HeartbeatVisualization from '@/components/HeartbeatVisualization';

<HeartbeatVisualization 
  items={[
    { id: 'api', name: 'API Server', state: 'active' },
    { id: 'db', name: 'Database', state: 'missed' },
    { id: 'cache', name: 'Cache', state: 'alert' }
  ]}
/>
```

## Asset Locations

### Icons & Logos
- Web icons: `libmat/web/` (favicon, apple-touch-icon, various sizes)
- Android icons: `libmat/android/res/mipmap-*/`
- iOS icons: `libmat/ios/`
- Public folders: `{app}/public/` (favicon.ico, apple-touch-icon.png, etc.)

## Color Usage Examples

| Element | Color | Hex | Usage |
|---------|-------|-----|-------|
| Primary Button | Transit Teal | #008080 | Main CTAs |
| Sidebar | Safe Slate | #2F4F4F | Navigation background |
| Active Heartbeat | Green | #22c55e | System healthy |
| Warning Alert | Amber | #FFBF00 | Caution state |
| Error Alert | Red | #ef4444 | Critical issues |
| Page Background | Cloud White | #F8F9FA | Clean UI |

## Dark Mode Support

All themes include dark mode CSS variables that maintain the brand colors while adjusting for dark mode contrast and readability. Dark mode can be toggled via the `.dark` class on the root element.

## References
- Brand guidelines: `libmat/fonts.txt`
- Component documentation: See individual component files
- Tailwind configuration: See `tailwind.config.js` in each app root
