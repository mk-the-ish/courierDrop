# Backend Coordinate Parsing Fix

## Problem
When users created parcel requests and corridor routes with picked coordinates (e.g., "-18.975780, 32.668756"), the `origin` and `destination` text fields were populated, but the PostGIS geography columns (`origin_point`, `destination_point`, `start_point`, `end_point`) remained null.

This prevented:
- Geographic queries and distance calculations
- Matching algorithms from working correctly
- Map-based features from accessing precise location data

## Solution
Updated both `parcels.js` and `corridors.js` backend routes to parse coordinate strings and convert them to proper PostGIS WKT (Well-Known Text) format before upserting to the database.

### Changes in `backend/src/routes/parcels.js`

**POST /parcels endpoint:**
- Added `parseCoordinates()` function to convert "latitude, longitude" strings to object format
- Validates that both origin and destination coordinates are properly formatted
- Converts parsed coordinates to PostGIS POINT format: `POINT(longitude latitude)`
- Includes `origin_point` and `destination_point` in the database payload

**Before:**
```javascript
const payload = {
  origin,
  destination,
  size: size || null,
  // ... origin_point and destination_point were NOT included
};
```

**After:**
```javascript
const parseCoordinates = (coordString) => {
  if (!coordString) return null;
  const parts = coordString.trim().split(",").map((s) => parseFloat(s.trim()));
  if (parts.length !== 2 || parts.some((p) => isNaN(p))) return null;
  const [lat, lng] = parts;
  return { lat, lng };
};

const originCoords = parseCoordinates(origin);
const destCoords = parseCoordinates(destination);

if (!originCoords) {
  throw new ApiError("Invalid origin coordinates format. Expected 'latitude, longitude'", 400, "PARCEL_INVALID_ORIGIN");
}

if (!destCoords) {
  throw new ApiError("Invalid destination coordinates format. Expected 'latitude, longitude'", 400, "PARCEL_INVALID_DESTINATION");
}

const payload = {
  origin,
  destination,
  origin_point: `POINT(${originCoords.lng} ${originCoords.lat})`,
  destination_point: `POINT(${destCoords.lng} ${destCoords.lat})`,
  // ... rest of payload
};
```

### Changes in `backend/src/routes/corridors.js`

**POST /corridors endpoint:**
- Added `parseCoordinates()` function (identical to parcels route)
- Parses `startLocation` and `endLocation` strings
- Converts to PostGIS SRID format: `SRID=4326;POINT(longitude latitude)`
- Includes `start_point` and `end_point` in the database payload if coordinates are valid

**Key Difference from Parcels:**
- Corridors use SRID=4326 prefix (Spatial Reference ID for WGS84)
- Gracefully handles missing coordinates (nullable, unlike parcels which are required)

## Testing

After deploying these changes, verify by:

1. Creating a new parcel request with coordinates:
   - Check if `origin_point` and `destination_point` are populated in the database
   - Should see WKT format like: `0101000020E6100000...` (binary) or `POINT(-17.8252 -17.8252)` (text)

2. Creating a new corridor route with start/end locations:
   - Check if `start_point` and `end_point` are populated
   - Should see SRID=4326 prefix in the WKT format

3. Verify geographic queries work:
   ```sql
   SELECT * FROM parcels 
   WHERE ST_DistanceSphere(origin_point, destination_point) < 50000 -- within 50km
   ```

## Database Format Reference

- **Input format** (from client): `"latitude, longitude"` (e.g., `"-17.8252, 31.0335"`)
- **PostGIS WKT format**: `POINT(longitude latitude)` (note: lon/lat order)
- **With SRID**: `SRID=4326;POINT(longitude latitude)`
- **Column type**: `geography(point, 4326)` - uses geographic coordinates (lon/lat)

## Backwards Compatibility

- Existing parcel/corridor records with null geography columns can be populated using:
  ```sql
  UPDATE parcels 
  SET origin_point = ST_GeographyFromText(CONCAT('POINT(', 
    SPLIT_PART(origin, ',', 2)::float, ' ', 
    SPLIT_PART(origin, ',', 1)::float, ')')),
      destination_point = ST_GeographyFromText(CONCAT('POINT(',
    SPLIT_PART(destination, ',', 2)::float, ' ',
    SPLIT_PART(destination, ',', 1)::float, ')'))
  WHERE origin_point IS NULL AND origin IS NOT NULL;
  ```

## Related Files
- `client/lib/screens/parcel_request_screen.dart` - Sends coordinates as "lat, lng" string
- `courier/lib/screens/route_declaration_screen.dart` - Sends route points via polyline
- `backend/sql/001_init.sql` - Database schema with geography columns
