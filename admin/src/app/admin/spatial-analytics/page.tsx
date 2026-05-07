"use client";

import { useEffect, useState } from "react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const baseUrl = process.env.NEXT_PUBLIC_API_URL || "https://dropcity-backend.onrender.com";

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
          "Content-Type": "application/json"
        }
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
      <PageHeader title="Spatial Analytics" description="Active corridors and dead zone clusters from offline batch sync failures" />

      <Card>
        <CardHeader>
          <CardTitle>Map Visualization (Tabular Coordinates)</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div>
              <h3 className="font-semibold mb-3">Active Corridors ({corridors.length})</h3>
              <div className="space-y-2 max-h-96 overflow-auto">
                {corridors.map((c) => (
                  <div key={c.id} className="rounded border p-3">
                    <div className="text-sm font-medium">{c.start_location} ? {c.end_location}</div>
                    <div className="text-xs text-gray-500 font-mono mt-1">{c.id}</div>
                    <div className="text-xs mt-1">Start: {c.start_point ? `${c.start_point.lat.toFixed(5)}, ${c.start_point.lng.toFixed(5)}` : "-"}</div>
                    <div className="text-xs">End: {c.end_point ? `${c.end_point.lat.toFixed(5)}, ${c.end_point.lng.toFixed(5)}` : "-"}</div>
                  </div>
                ))}
                {corridors.length === 0 && <p className="text-sm text-gray-500">No active corridors.</p>}
              </div>
            </div>

            <div>
              <h3 className="font-semibold mb-3">Dead Zone Clusters ({deadZones.length})</h3>
              <div className="space-y-2 max-h-96 overflow-auto">
                {deadZones.map((z) => (
                  <div key={`${z.lat},${z.lng}`} className="rounded border p-3">
                    <div className="text-sm font-medium">{z.lat.toFixed(3)}, {z.lng.toFixed(3)}</div>
                    <div className="text-xs">Failures: {z.count}</div>
                    <div className="text-xs text-gray-600">Reasons: {Object.entries(z.reasons).map(([k, v]) => `${k}:${v}`).join(", ")}</div>
                  </div>
                ))}
                {deadZones.length === 0 && <p className="text-sm text-gray-500">No dead zones in selected period.</p>}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
