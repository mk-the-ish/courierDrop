"use client";

import { useEffect, useState } from "react";
import { AlertCircle } from "lucide-react";
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

type Rule = {
  id: string;
  type: string;
  threshold?: number;
  time_window_minutes?: number;
  enabled?: boolean;
};

export default function AlertsPage() {
  const [routeDeviationMeters, setRouteDeviationMeters] = useState("500");
  const [inactivityMinutes, setInactivityMinutes] = useState("15");
  const [rules, setRules] = useState<Rule[]>([]);
  const [saving, setSaving] = useState(false);

  const load = async () => {
    const token = adminToken();
    const res = await fetch(`${baseUrl}/admin/alerts/rules`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const data = await res.json();
    const list: Rule[] = data.rules || [];
    setRules(list);
    const deviation = list.find((r) => r.type === "ROUTE_DEVIATION");
    const inactivity = list.find((r) => r.type === "INACTIVITY_TIMEOUT");
    if (deviation?.threshold) setRouteDeviationMeters(String(deviation.threshold));
    if (inactivity?.time_window_minutes) {
      setInactivityMinutes(String(inactivity.time_window_minutes));
    }
  };

  useEffect(() => {
    load();
  }, []);

  const upsertRule = async (type: string, payload: any) => {
    const token = adminToken();
    const existing = rules.find((r) => r.type === type);
    if (existing) {
      await fetch(`${baseUrl}/admin/alerts/rules/${existing.id}`, {
        method: "PATCH",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });
      return;
    }
    await fetch(`${baseUrl}/admin/alerts/rules`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        type,
        name: type === "ROUTE_DEVIATION" ? "Route Deviation" : "Inactivity Timeout",
        description: "Generated from admin alert controls",
        threshold: payload.threshold,
        time_window_minutes: payload.time_window_minutes,
        severity: "warning",
        notification_channels: "slack",
      }),
    });
  };

  const save = async () => {
    setSaving(true);
    try {
      await upsertRule("ROUTE_DEVIATION", {
        threshold: Number(routeDeviationMeters),
        enabled: true,
      });
      await upsertRule("INACTIVITY_TIMEOUT", {
        threshold: 1,
        time_window_minutes: Number(inactivityMinutes),
        enabled: true,
      });
      await load();
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="flex flex-col gap-8 p-8">
      <PageHeader
        title="Alert Rules"
        description="Configure route-deviation and inactivity thresholds"
      />

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <AlertCircle className="h-4 w-4" />
            Tracking Alert Thresholds
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-5">
          <div className="space-y-2">
            <Label htmlFor="deviation">Route Deviation Threshold (meters)</Label>
            <Input
              id="deviation"
              value={routeDeviationMeters}
              onChange={(e) => setRouteDeviationMeters(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="inactivity">Inactivity Timeout (minutes)</Label>
            <Input
              id="inactivity"
              value={inactivityMinutes}
              onChange={(e) => setInactivityMinutes(e.target.value)}
            />
          </div>
          <Button onClick={save} disabled={saving}>
            {saving ? "Saving..." : "Save Alert Rules"}
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
