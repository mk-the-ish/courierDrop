"use client";

import { useEffect, useState } from "react";
import { Settings } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const baseUrl =
  process.env.NEXT_PUBLIC_API_URL || "https://dropcity-backend.onrender.com";

function adminToken() {
  if (typeof window === "undefined") return "";
  return localStorage.getItem("admin_token") || localStorage.getItem("adminToken") || "";
}

export default function SettingsPage() {
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [matchingBuffer, setMatchingBuffer] = useState("500");
  const [routeDeviation, setRouteDeviation] = useState("500");
  const [inactivityTimeout, setInactivityTimeout] = useState("15");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const load = async () => {
      const token = adminToken();
      const res = await fetch(`${baseUrl}/admin/settings`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      const map = new Map<string, unknown>(
        (data.settings || []).map((row: any) => [row.key, row.value]),
      );
      setMaintenanceMode(Boolean(map.get("maintenance_mode")));
      setMatchingBuffer(String(map.get("global_matching_buffer_m") ?? "500"));
      setRouteDeviation(String(map.get("route_deviation_threshold_m") ?? "500"));
      setInactivityTimeout(String(map.get("inactivity_timeout_minutes") ?? "15"));
    };
    load();
  }, []);

  const save = async () => {
    setSaving(true);
    try {
      const token = adminToken();
      await fetch(`${baseUrl}/admin/settings`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          settings: [
            { key: "maintenance_mode", value: maintenanceMode },
            { key: "global_matching_buffer_m", value: Number(matchingBuffer) },
            { key: "route_deviation_threshold_m", value: Number(routeDeviation) },
            { key: "inactivity_timeout_minutes", value: Number(inactivityTimeout) },
          ],
        }),
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="flex flex-col gap-8 p-8">
      <PageHeader
        title="Settings"
        description="Global toggles and matching thresholds"
      />

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Settings className="h-4 w-4" />
            System Configuration
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="flex items-center justify-between rounded border p-3">
            <div>
              <p className="font-medium">Maintenance Mode</p>
              <p className="text-sm text-muted-foreground">
                Temporarily pause normal platform operations.
              </p>
            </div>
            <input
              type="checkbox"
              checked={maintenanceMode}
              onChange={(e) => setMaintenanceMode(e.target.checked)}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="matching-buffer">Global Matching Buffer Size (m)</Label>
            <Input
              id="matching-buffer"
              value={matchingBuffer}
              onChange={(e) => setMatchingBuffer(e.target.value)}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="route-deviation">Route Deviation Threshold (m)</Label>
            <Input
              id="route-deviation"
              value={routeDeviation}
              onChange={(e) => setRouteDeviation(e.target.value)}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="inactivity-timeout">Inactivity Timeout (minutes)</Label>
            <Input
              id="inactivity-timeout"
              value={inactivityTimeout}
              onChange={(e) => setInactivityTimeout(e.target.value)}
            />
          </div>

          <Button onClick={save} disabled={saving}>
            {saving ? "Saving..." : "Save Settings"}
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
