"use client";

import { useEffect, useState } from "react";
import { MapPinned, Route } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import StatCard from "@/components/StatCard";
import CorridorOsmMap from "@/components/corridor-osm-map";
import { getApiBaseUrl } from "@/lib/api-base-url";

const baseUrl = getApiBaseUrl();

type Corridor = {
  id: string;
  start_location: string;
  end_location: string;
  start_point: { lat: number; lng: number } | null;
  end_point: { lat: number; lng: number } | null;
};

type DeadZone = {
  lat: number;
  lng: number;
  count: number;
  reasons: Record<string, number>;
};

export default function SpatialAnalyticsPage() {
  const [corridors, setCorridors] = useState<Corridor[]>([]);
  const [deadZones, setDeadZones] = useState<DeadZone[]>([]);

  useEffect(() => {
    const run = async () => {
      const token = localStorage.getItem("admin_token") || localStorage.getItem("adminToken");
      const res = await fetch(`${baseUrl}/admin/spatial-analytics?days=14`, {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });
      if (!res.ok) {
        setCorridors([]);
        setDeadZones([]);
        return;
      }
      const data = await res.json();
      setCorridors(data.active_corridors || []);
      setDeadZones(data.dead_zone_clusters || []);
    };
    run();
  }, []);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Spatial Analytics"
        description="Active corridors and dead zone clusters surfaced from the live route telemetry feed."
      />

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard title="Active Corridors" value={corridors.length} icon={Route} color="teal" />
        <StatCard title="Dead Zone Clusters" value={deadZones.length} icon={MapPinned} color="amber" />
        <StatCard title="Failure Density" value={deadZones.reduce((sum, zone) => sum + zone.count, 0)} icon={MapPinned} color="red" />
      </div>

      <Card>
        <CardHeader>
          <p className="micro-label">OpenStreetMap Corridor View</p>
          <CardTitle>Corridor geometry and dead zone overlays</CardTitle>
        </CardHeader>
        <CardContent>
          <CorridorOsmMap corridors={corridors} deadZones={deadZones} className="h-[460px] w-full" />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <p className="micro-label">Spatial Overview</p>
          <CardTitle>Corridors and Dead Zones</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-6 lg:grid-cols-2">
            <div>
              <h3 className="mb-3 text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                Active Corridors ({corridors.length})
              </h3>
              <div className="space-y-2 max-h-96 overflow-auto pr-1">
                {corridors.map((c) => (
                  <div key={c.id} className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <div className="text-sm font-medium text-slate-100">
                      {c.start_location} → {c.end_location}
                    </div>
                    <div className="mt-1 font-mono text-xs text-slate-500">{c.id}</div>
                    <div className="mt-2 text-xs text-slate-300">
                      Start: {c.start_point ? `${c.start_point.lat.toFixed(5)}, ${c.start_point.lng.toFixed(5)}` : "-"}
                    </div>
                    <div className="text-xs text-slate-300">
                      End: {c.end_point ? `${c.end_point.lat.toFixed(5)}, ${c.end_point.lng.toFixed(5)}` : "-"}
                    </div>
                  </div>
                ))}
                {corridors.length === 0 && <p className="text-sm text-slate-400">No active corridors.</p>}
              </div>
            </div>

            <div>
              <h3 className="mb-3 text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                Dead Zone Clusters ({deadZones.length})
              </h3>
              <div className="space-y-2 max-h-96 overflow-auto pr-1">
                {deadZones.map((z) => (
                  <div key={`${z.lat},${z.lng}`} className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <div className="text-sm font-medium text-slate-100">
                      {z.lat.toFixed(3)}, {z.lng.toFixed(3)}
                    </div>
                    <div className="mt-1 text-xs text-slate-300">Failures: {z.count}</div>
                    <div className="mt-1 text-xs text-slate-500">
                      Reasons: {Object.entries(z.reasons).map(([key, value]) => `${key}:${value}`).join(", ")}
                    </div>
                  </div>
                ))}
                {deadZones.length === 0 && <p className="text-sm text-slate-400">No dead zones in selected period.</p>}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
