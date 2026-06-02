'use client';

import { useEffect, useMemo, useRef, useState } from 'react';

type GeoPoint = { lat: number; lng: number };

type Corridor = {
  id: string;
  start_location: string;
  end_location: string;
  start_point: GeoPoint | null;
  end_point: GeoPoint | null;
};

type DeadZone = {
  lat: number;
  lng: number;
  count: number;
  reasons: Record<string, number>;
};

type CorridorOsmMapProps = {
  corridors: Corridor[];
  deadZones?: DeadZone[];
  className?: string;
};

const TILE_SIZE = 256;
const OSM_TILE = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

function project(point: GeoPoint, zoom: number) {
  const scale = TILE_SIZE * 2 ** zoom;
  const sinLat = Math.sin((point.lat * Math.PI) / 180);
  const x = ((point.lng + 180) / 360) * scale;
  const y =
    (0.5 - Math.log((1 + sinLat) / (1 - sinLat)) / (4 * Math.PI)) * scale;
  return { x, y };
}


function fitZoom(bounds: { minLat: number; maxLat: number; minLng: number; maxLng: number }, width: number, height: number) {
  const paddedWidth = Math.max(width - 48, 240);
  const paddedHeight = Math.max(height - 48, 240);
  for (let zoom = 14; zoom >= 3; zoom -= 1) {
    const topLeft = project({ lat: bounds.maxLat, lng: bounds.minLng }, zoom);
    const bottomRight = project({ lat: bounds.minLat, lng: bounds.maxLng }, zoom);
    const spanX = Math.abs(bottomRight.x - topLeft.x);
    const spanY = Math.abs(bottomRight.y - topLeft.y);
    if (spanX <= paddedWidth && spanY <= paddedHeight) {
      return zoom;
    }
  }
  return 3;
}

export default function CorridorOsmMap({ corridors, deadZones = [], className }: CorridorOsmMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [size, setSize] = useState({ width: 0, height: 0 });

  useEffect(() => {
    const node = containerRef.current;
    if (!node) return;

    const update = () => setSize({ width: node.clientWidth, height: node.clientHeight });
    update();

    const observer = new ResizeObserver(update);
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  const points = useMemo(() => {
    const corridorPoints = corridors.flatMap((corridor) => [corridor.start_point, corridor.end_point].filter(Boolean) as GeoPoint[]);
    const deadZonePoints = deadZones.map((zone) => ({ lat: zone.lat, lng: zone.lng }));
    return [...corridorPoints, ...deadZonePoints];
  }, [corridors, deadZones]);

  const bounds = useMemo(() => {
    if (points.length === 0) {
      return null;
    }
    return points.reduce(
      (acc, point) => ({
        minLat: Math.min(acc.minLat, point.lat),
        maxLat: Math.max(acc.maxLat, point.lat),
        minLng: Math.min(acc.minLng, point.lng),
        maxLng: Math.max(acc.maxLng, point.lng),
      }),
      { minLat: points[0].lat, maxLat: points[0].lat, minLng: points[0].lng, maxLng: points[0].lng }
    );
  }, [points]);

  const view = useMemo(() => {
    if (!bounds || size.width === 0 || size.height === 0) {
      return null;
    }

    const zoom = fitZoom(bounds, size.width, size.height);
    const center = {
      lat: (bounds.minLat + bounds.maxLat) / 2,
      lng: (bounds.minLng + bounds.maxLng) / 2,
    };
    const centerWorld = project(center, zoom);
    const topLeftWorld = { x: centerWorld.x - size.width / 2, y: centerWorld.y - size.height / 2 };
    const bottomRightWorld = { x: centerWorld.x + size.width / 2, y: centerWorld.y + size.height / 2 };

    const minTileX = Math.floor(topLeftWorld.x / TILE_SIZE);
    const maxTileX = Math.floor(bottomRightWorld.x / TILE_SIZE);
    const minTileY = Math.floor(topLeftWorld.y / TILE_SIZE);
    const maxTileY = Math.floor(bottomRightWorld.y / TILE_SIZE);

    const tileOrigin = {
      x: topLeftWorld.x - Math.floor(topLeftWorld.x / TILE_SIZE) * TILE_SIZE,
      y: topLeftWorld.y - Math.floor(topLeftWorld.y / TILE_SIZE) * TILE_SIZE,
    };

    return {
      zoom,
      center,
      topLeftWorld,
      minTileX,
      maxTileX,
      minTileY,
      maxTileY,
      tileOrigin,
    };
  }, [bounds, size.height, size.width]);

  const mapItems = useMemo(() => {
    if (!view) {
      return { corridorLines: [], deadZoneMarkers: [] };
    }

    const corridorLines = corridors
      .filter((corridor) => corridor.start_point && corridor.end_point)
      .map((corridor, index) => {
        const start = project(corridor.start_point as GeoPoint, view.zoom);
        const end = project(corridor.end_point as GeoPoint, view.zoom);
        const color = ['#FF6B35', '#8B5CF6', '#14B8A6', '#F59E0B'][index % 4];
        return {
          key: corridor.id,
          label: `${corridor.start_location} → ${corridor.end_location}`,
          start: { x: start.x - view.topLeftWorld.x, y: start.y - view.topLeftWorld.y },
          end: { x: end.x - view.topLeftWorld.x, y: end.y - view.topLeftWorld.y },
          color,
          startPoint: corridor.start_point as GeoPoint,
          endPoint: corridor.end_point as GeoPoint,
        };
      });

    const deadZoneMarkers = deadZones.map((zone) => {
      const point = project({ lat: zone.lat, lng: zone.lng }, view.zoom);
      return {
        key: `${zone.lat},${zone.lng}`,
        point: { x: point.x - view.topLeftWorld.x, y: point.y - view.topLeftWorld.y },
        count: zone.count,
      };
    });

    return { corridorLines, deadZoneMarkers };
  }, [corridors, deadZones, view]);

  return (
    <div ref={containerRef} className={className ?? 'h-[420px] w-full'}>
      {!view ? (
        <div className="flex h-full items-center justify-center rounded-2xl border border-dashed border-white/10 bg-slate-950/60 text-sm text-slate-400">
          Loading map...
        </div>
      ) : (
        <div className="relative h-full w-full overflow-hidden rounded-2xl border border-white/10 bg-slate-950">
          <div className="absolute inset-0">
            {Array.from({ length: view.maxTileX - view.minTileX + 1 }).flatMap((_, colIndex) =>
              Array.from({ length: view.maxTileY - view.minTileY + 1 }).map((__, rowIndex) => {
                const x = view.minTileX + colIndex;
                const y = view.minTileY + rowIndex;
                const left = x * TILE_SIZE - view.topLeftWorld.x;
                const top = y * TILE_SIZE - view.topLeftWorld.y;
                return (
                  <img
                    key={`${x}-${y}`}
                    src={OSM_TILE.replace('{z}', String(view.zoom)).replace('{x}', String(x)).replace('{y}', String(y))}
                    alt=""
                    className="absolute h-[256px] w-[256px] select-none object-cover"
                    style={{ left, top }}
                    draggable={false}
                  />
                );
              })
            )}
          </div>

          <svg className="absolute inset-0 h-full w-full">
            <defs>
              <filter id="corridorShadow" x="-20%" y="-20%" width="140%" height="140%">
                <feDropShadow dx="0" dy="2" stdDeviation="3" floodColor="rgba(0,0,0,0.35)" />
              </filter>
            </defs>

            {mapItems.corridorLines.map((line) => (
              <g key={line.key} filter="url(#corridorShadow)">
                <line
                  x1={line.start.x}
                  y1={line.start.y}
                  x2={line.end.x}
                  y2={line.end.y}
                  stroke={line.color}
                  strokeWidth="4"
                  strokeLinecap="round"
                  strokeDasharray="10 7"
                />
                <circle cx={line.start.x} cy={line.start.y} r="7" fill={line.color} stroke="#fff" strokeWidth="2" />
                <circle cx={line.end.x} cy={line.end.y} r="7" fill={line.color} stroke="#fff" strokeWidth="2" />
                <text x={line.start.x + 10} y={line.start.y - 10} fill="#E5E7EB" fontSize="12" fontFamily="ui-sans-serif">
                  {line.label}
                </text>
              </g>
            ))}

            {mapItems.deadZoneMarkers.map((marker) => (
              <g key={marker.key}>
                <circle cx={marker.point.x} cy={marker.point.y} r="10" fill="rgba(239, 68, 68, 0.35)" />
                <circle cx={marker.point.x} cy={marker.point.y} r="5" fill="#EF4444" stroke="#fff" strokeWidth="2" />
                <text x={marker.point.x + 12} y={marker.point.y + 4} fill="#FCA5A5" fontSize="11" fontFamily="ui-sans-serif">
                  {marker.count}
                </text>
              </g>
            ))}
          </svg>

          <div className="absolute left-4 top-4 rounded-2xl border border-white/10 bg-slate-950/85 px-3 py-2 text-xs text-slate-300 shadow-lg backdrop-blur">
            <p className="font-semibold text-slate-100">OpenStreetMap corridor view</p>
            <p className="mt-1 text-slate-400">Dashed routes show active corridor spans; red dots show dead zone clusters.</p>
          </div>

          <div className="absolute bottom-4 right-4 rounded-2xl border border-white/10 bg-slate-950/85 px-3 py-2 text-[11px] text-slate-400 shadow-lg backdrop-blur">
            © OpenStreetMap contributors
          </div>
        </div>
      )}
    </div>
  );
}
