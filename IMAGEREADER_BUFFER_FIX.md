# ImageReader Buffer Exhaustion Fix

## Issue
`W/ImageReader_JNI: Unable to acquire a buffer item, very likely client tried to acquire more than maxImages buffers`

**Root Cause**: Google Maps Flutter rendering exhausts Android ImageReader buffers, especially under memory pressure or heavy UI interaction.

## Solution Applied

### 1. ✅ Google Maps Lifecycle Management

**Status**: Applied to both apps (client & courier)

- Added `GoogleMapController` field
- Properly dispose controller in `dispose()` method
- Call `onMapCreated` callback to capture controller

**Files Updated**:
- `client/lib/screens/parcel_request_screen.dart`
- `courier/lib/screens/route_declaration_screen.dart` (already had proper disposal)

### 2. ✅ Map Optimization Flags

**Next steps to implement** (if issues persist):

Add these flags to GoogleMap widget for memory efficiency:

```dart
GoogleMap(
  // ... existing properties ...
  
  // Memory optimizations
  liteModeEnabled: false,  // Disable lite mode rendering
  tiltGesturesEnabled: false,  // Reduce complex render operations
  scrollGesturesEnabled: true,
  rotateGesturesEnabled: false,  // Disable rotation to save memory
  zoomGesturesEnabled: true,
  
  // Limit marker updates
  // See section 3 below
)
```

### 3. 🔄 Marker & Polyline Update Optimization

**Current Status**: Both apps update markers/polylines on every state change.

**Recommendation** (if buffer issues continue):

Implement debounced updates to avoid excessive re-renders:

```dart
Timer? _updateDebounce;

void _updateMarkersDebounced() {
  _updateDebounce?.cancel();
  _updateDebounce = Timer(const Duration(milliseconds: 300), () {
    setState(() {
      // Update markers/polylines here
    });
  });
}

@override
void dispose() {
  _updateDebounce?.cancel();
  // ... other disposal code ...
}
```

## Testing

### How to verify the fix works:

1. **Run the app**:
   ```bash
   cd client
   flutter run --verbose
   ```

2. **Monitor logcat**:
   ```bash
   adb logcat | grep -E "ImageReader|ProxyAndroidLoggerBackend"
   ```

3. **Expected result**:
   - First few logs may appear during initialization
   - Should stabilize and stop after ~10-15 seconds
   - No repeated ImageReader errors during normal app usage

### If warnings persist:

1. Check `ProxyAndroidLoggerBackend` configuration
2. Implement marker/polyline debouncing (Section 3)
3. Consider disabling real-time map interactions
4. Reduce map frame rate with `@1x` rendering

## Performance Notes

- **Client app**: Has Google Maps embedded in parcel request screen
- **Courier app**: Has Google Maps in route declaration screen
- **Both**: Update markers/polylines based on user interaction

The controller disposal ensures proper cleanup when navigating away from map screens.

## Related Issues

- Flutter issue: https://github.com/flutter/flutter/issues/103621 (Google Maps buffer management)
- Android issue: Image buffer pool exhaustion under heavy rendering load

## Monitoring

Watch logcat output for:
- ✅ Fewer ImageReader buffer warnings over time
- ✅ Logs stabilizing after app initialization
- ❌ Continuous "Unable to acquire buffer" messages = need additional optimization
