# Icon and Logo Integration Instructions

## Overview
This guide explains how to integrate the brand icons and logos from `libmat/` into each frontend application for use as app icons and in-app branding elements.

## Asset Locations in libmat/

### Web Assets (`libmat/web/`)
- `favicon.ico` - Favicon for browser tabs
- `apple-touch-icon.png` - iOS home screen icon (180x180)
- `icon-192.png` - PWA icon standard
- `icon-512.png` - PWA icon large
- `icon-192-maskable.png` - Maskable icon for adaptive display
- `icon-512-maskable.png` - Maskable icon for adaptive display

### Android Assets (`libmat/android/res/`)
- `mipmap-mdpi/` - Medium DPI (160dpi) icons
- `mipmap-hdpi/` - High DPI (240dpi) icons
- `mipmap-xhdpi/` - Extra high DPI (320dpi) icons
- `mipmap-xxhdpi/` - Extra extra high DPI (480dpi) icons
- `mipmap-xxxhdpi/` - Extra extra extra high DPI (640dpi) icons
- `play_store_512.png` - Google Play Store listing icon

### iOS Assets (`libmat/ios/`)
Multiple AppIcon variants for different iOS device configurations and sizes (20x20 to 1024x1024)

## Integration by App

### Admin Dashboard

#### Step 1: Copy Web Assets
```bash
cp libmat/web/* admin/public/
```

#### Step 2: Update HTML Head
Add to `admin/pages/_document.js` or `admin/app/layout.tsx` (if applicable):
```html
<link rel="icon" href="/favicon.ico" sizes="any">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
```

#### Step 3: Update next.config.js
```javascript
module.exports = {
  // ... other config
  images: {
    domains: [],
  },
  publicRuntimeConfig: {
    NEXT_PUBLIC_APP_NAME: 'DropCity Admin',
  }
}
```

#### Step 4: Add Manifest (Optional but recommended)
Create `admin/public/manifest.json`:
```json
{
  "name": "DropCity Admin Dashboard",
  "short_name": "DropCity Admin",
  "description": "DropCity Administrative Dashboard",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#F8F9FA",
  "theme_color": "#008080",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "/favicon.ico",
      "type": "image/x-icon",
      "sizes": "16x16 32x32"
    },
    {
      "src": "/icon-192.png",
      "type": "image/png",
      "sizes": "192x192",
      "purpose": "any"
    },
    {
      "src": "/icon-512.png",
      "type": "image/png",
      "sizes": "512x512",
      "purpose": "any"
    },
    {
      "src": "/icon-192-maskable.png",
      "type": "image/png",
      "sizes": "192x192",
      "purpose": "maskable"
    },
    {
      "src": "/icon-512-maskable.png",
      "type": "image/png",
      "sizes": "512x512",
      "purpose": "maskable"
    }
  ]
}
```

Add to `admin/pages/_document.js`:
```jsx
<link rel="manifest" href="/manifest.json">
<meta name="theme-color" content="#008080">
<meta name="description" content="DropCity Administrative Dashboard">
```

### Ops Dashboard

#### Step 1: Copy Web Assets
```bash
cp libmat/web/* ops/public/
```

#### Step 2: Update Next.js Config
Add favicon reference to `ops/src/app/layout.tsx`:
```tsx
import { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'DropCity Ops Dashboard',
  description: 'DropCity Operations Dashboard',
  icons: {
    icon: '/favicon.ico',
    apple: '/apple-touch-icon.png',
  },
  manifest: '/manifest.json',
};
```

#### Step 3: Create Manifest
Create `ops/public/manifest.json` (same as admin but with "DropCity Ops Dashboard" name)

### Courier Flutter App

#### Step 1: Android Icons
Copy Android assets:
```bash
cp libmat/android/res/mipmap-* courier/android/app/src/main/res/
```

Update `courier/android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:label="@string/app_name"
    android:icon="@mipmap/ic_launcher"
    android:roundIcon="@mipmap/ic_launcher_round">
</application>
```

#### Step 2: iOS Icons
Copy iOS assets:
```bash
cp libmat/ios/AppIcon* courier/ios/Runner/Assets.xcassets/AppIcon.appiconset/
cp libmat/ios/Contents.json courier/ios/Runner/Assets.xcassets/AppIcon.appiconset/
```

Update in Xcode or modify `courier/ios/Runner/Info.plist`:
```xml
<key>CFBundleIcons</key>
<dict>
  <key>CFBundleAlternateIcons</key>
  <dict>
    <key>AppIcon</key>
    <dict>
      <key>CFBundleIconFiles</key>
      <array>
        <string>AppIcon</string>
      </array>
    </dict>
  </dict>
</dict>
```

#### Step 3: Web Icons (if applicable)
```bash
mkdir -p courier/web/public
cp libmat/web/* courier/web/public/
```

### Client Flutter App

Same process as Courier:

#### Android
```bash
cp libmat/android/res/mipmap-* client/android/app/src/main/res/
```

#### iOS
```bash
cp libmat/ios/AppIcon* client/ios/Runner/Assets.xcassets/AppIcon.appiconset/
cp libmat/ios/Contents.json client/ios/Runner/Assets.xcassets/AppIcon.appiconset/
```

#### Web
```bash
mkdir -p client/web/public
cp libmat/web/* client/web/public/
```

## In-App Logo Usage

### Admin Dashboard Component
```jsx
// admin/src/components/Sidebar.js
<div className="w-8 h-8 bg-transit-teal rounded-lg flex items-center justify-center">
  📦
</div>
```

Replace emoji with actual logo image:
```jsx
import Image from 'next/image';

<Image
  src="/icon-192.png"
  alt="DropCity"
  width={32}
  height={32}
  className="rounded-lg"
/>
```

### Branding Header Component (Optional)
Create `admin/src/components/BrandHeader.js`:
```jsx
import Image from 'next/image';

export default function BrandHeader() {
  return (
    <div className="flex items-center gap-3">
      <Image
        src="/icon-192.png"
        alt="DropCity Logo"
        width={40}
        height={40}
        className="rounded-lg"
      />
      <div>
        <h1 className="text-xl font-bold text-safe-slate">DropCity</h1>
        <p className="text-xs text-gray-600">Admin Dashboard</p>
      </div>
    </div>
  );
}
```

## Verification Checklist

- [ ] favicon.ico appears in browser tab
- [ ] Apple touch icon displays when adding to home screen
- [ ] PWA manifest is valid and loads correctly
- [ ] Android app shows logo on home screen
- [ ] iOS app shows logo on home screen
- [ ] In-app logo displays correctly in all pages
- [ ] Logo respects brand colors (Transit Teal background)
- [ ] Icons are properly sized for different DPIs
- [ ] Manifest has correct theme color (#008080)
- [ ] Maskable icons work for adaptive icon support

## Additional Resources

- libmat/web/README.txt - Web integration instructions
- Brand guidelines: libmat/fonts.txt
- Theme guide: BRAND_THEME_GUIDE.md

## Color Reference for Icon Customization

If you need to customize icons:
- Background: Transit Teal (#008080)
- Accent: Alert Amber (#FFBF00)
- Text: Cloud White (#F8F9FA)
- Dark variant: Safe Slate (#2F4F4F)
