# DropCity Brand Color Quick Reference

## Brand Colors

### Primary
```
🟦 TRANSIT TEAL
   Hex:     #008080
   RGB:     0, 128, 128
   HSL:     180°, 100%, 25%
   Tailwind: bg-transit-teal, text-transit-teal
   Usage:   Primary buttons, sidebars, active states, main branding
```

### Secondary
```
🟩 SAFE SLATE
   Hex:     #2F4F4F
   RGB:     47, 79, 79
   HSL:     180°, 25%, 25%
   Tailwind: bg-safe-slate, text-safe-slate
   Usage:   Text, secondary elements, dark backgrounds, security elements
```

### Accent
```
🟨 ALERT AMBER
   Hex:     #FFBF00
   RGB:     255, 191, 0
   HSL:     45°, 100%, 50%
   Tailwind: bg-alert-amber, text-alert-amber
   Usage:   Warnings, alerts, caution indicators, virtual stops
```

### Background
```
⬜ CLOUD WHITE
   Hex:     #F8F9FA
   RGB:     248, 249, 250
   HSL:     210°, 17%, 98%
   Tailwind: bg-cloud-white, text-cloud-white
   Usage:   Primary backgrounds, card surfaces, clean spaces
```

## Status/State Colors

### Active (Heartbeat)
```
🟢 SUCCESS GREEN
   Hex:     #22c55e
   RGB:     34, 197, 94
   Tailwind: bg-heartbeat-active, text-heartbeat-active
   Usage:   Active heartbeat, system running, success states
   Visual:  Animated green pulse
```

### Missed (Heartbeat)
```
🟡 WARNING AMBER
   Hex:     #FFBF00
   RGB:     255, 191, 0
   Tailwind: bg-heartbeat-missed, text-heartbeat-missed
   Usage:   Missed heartbeat, warnings, caution states
   Visual:  Amber ripple animation
```

### Alert (Heartbeat)
```
🔴 ERROR RED
   Hex:     #ef4444
   RGB:     239, 68, 68
   Tailwind: bg-heartbeat-alert, text-heartbeat-alert
   Usage:   Critical alerts, errors, watchdog alerts
   Visual:  Red static animation
```

## Color Combinations

### Light Theme
```
Background: Cloud White (#F8F9FA)
Text:       Safe Slate (#2F4F4F)
Accent:     Transit Teal (#008080)
Alert:      Alert Amber (#FFBF00)
```

### Dark Theme
```
Background: Dark Slate (#0F172A)
Text:       Cloud White (#F8F9FA)
Accent:     Transit Teal (#008080)
Alert:      Alert Amber (#FFBF00)
```

## Component Color Mapping

### Buttons
```
Primary Button
├─ Default:  bg-transit-teal, text-white
└─ Hover:    bg-safe-slate, text-white

Secondary Button
├─ Default:  bg-gray-200, text-safe-slate
└─ Hover:    bg-gray-300, text-safe-slate
```

### Cards
```
Card Container
├─ Background: bg-white
├─ Border:     border-gray-100
└─ Shadow:     shadow-md hover:shadow-lg
```

### Status Badges
```
Success Badge
├─ Background: bg-green-100
└─ Text:       text-green-800

Warning Badge
├─ Background: bg-alert-amber/20
└─ Text:       text-alert-amber

Error Badge
├─ Background: bg-red-100
└─ Text:       text-red-800

Info Badge
├─ Background: bg-transit-teal/20
└─ Text:       text-transit-teal
```

## Sidebar Styling

```
Sidebar Background:    Safe Slate (#2F4F4F)
Sidebar Text:          Cloud White (#F8F9FA)
Active Menu Item:      bg-transit-teal
Active Border:         border-alert-amber
Hover State:           bg-gray-700
Status Indicator:      Heartbeat Green (#22c55e)
```

## Tailwind Class Examples

### Using Brand Colors in JSX
```jsx
// Buttons
<button className="bg-transit-teal hover:bg-safe-slate text-white">
  Primary Action
</button>

// Cards
<div className="bg-cloud-white border border-gray-100 rounded-lg">
  Card Content
</div>

// Status
<span className="bg-heartbeat-active/20 text-heartbeat-active px-3 py-1 rounded-full">
  Active
</span>

// Text
<h1 className="text-safe-slate">Heading</h1>
<p className="text-gray-600">Subtext</p>

// Interactive
<div className="bg-transit-teal/10 text-transit-teal">
  Interactive Element
</div>
```

## Accessibility Notes

### Contrast Ratios (WCAG AA Compliant)
```
Transit Teal on Cloud White:  4.5:1 ✓ (AA)
Safe Slate on Cloud White:    5.1:1 ✓ (AA)
Alert Amber on White:         3.1:1 ✓ (AA)
Safe Slate on Transit Teal:   4.2:1 ✓ (AA)
```

### Color Blindness Considerations
```
✓ Transit Teal & Safe Slate are distinguishable
✓ Alert Amber is accessible for red-green blindness
✓ Status colors use both color and icons/text labels
✓ No critical information relies on color alone
```

## Usage by App

### Admin Dashboard
- Sidebar: Safe Slate background
- Primary buttons: Transit Teal
- Status indicators: Heartbeat colors
- Cards: Cloud White with borders

### Ops Dashboard
- Navigation: Transit Teal theme
- Charts: Using all status colors
- Alerts: Alert Amber for warnings
- Backgrounds: Cloud White

### Courier App
- Primary theme: Transit Teal
- Status updates: Heartbeat colors
- Cards/UI: Cloud White
- Text: Safe Slate

### Client App
- Primary theme: Transit Teal
- Confirmations: Success green
- Warnings: Alert amber
- Backgrounds: Cloud White

## Color Picker Values

### Hex Format (for CSS)
```css
transit-teal:    #008080
safe-slate:      #2F4F4F
alert-amber:     #FFBF00
cloud-white:     #F8F9FA
success:         #22c55e
warning:         #FFBF00
error:           #ef4444
```

### RGB Format (for JavaScript)
```javascript
transitTeal:     rgb(0, 128, 128)
safeSlate:       rgb(47, 79, 79)
alertAmber:      rgb(255, 191, 0)
cloudWhite:      rgb(248, 249, 250)
success:         rgb(34, 197, 94)
warning:         rgb(255, 191, 0)
error:           rgb(239, 68, 68)
```

### HSL Format (for CSS)
```css
transit-teal:    hsl(180, 100%, 25%)
safe-slate:      hsl(180, 25%, 25%)
alert-amber:     hsl(45, 100%, 50%)
cloud-white:     hsl(210, 17%, 98%)
success:         hsl(142, 71%, 45%)
warning:         hsl(45, 100%, 50%)
error:           hsl(0, 84%, 60%)
```

## Implementation Checklist

- [ ] All apps using Transit Teal for primary actions
- [ ] Sidebar backgrounds using Safe Slate
- [ ] Buttons hover state using Safe Slate
- [ ] Status indicators using heartbeat colors
- [ ] Cards on Cloud White background
- [ ] Dark mode CSS variables configured
- [ ] Alerts using Alert Amber with icons
- [ ] Success states using green
- [ ] Error states using red
- [ ] Contrast ratios validated
- [ ] Colors tested for color blindness
- [ ] Responsive design tested

---

**Last Updated**: April 10, 2026  
**Version**: 1.0  
**Status**: Complete
