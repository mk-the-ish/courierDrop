"use client";

import { useEffect, useMemo, useState } from "react";
import { Activity } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

const baseUrl =
  process.env.NEXT_PUBLIC_API_URL || "https://dropcity-backend.onrender.com";

type Heartbeat = {
  job_name: string;
  last_heartbeat_at: string;
  expected_frequency_sec: number;
  status: string;
};

function adminToken() {
  if (typeof window === "undefined") return "";
  return localStorage.getItem("admin_token") || localStorage.getItem("adminToken") || "";
}

export default function HealthPage() {
  const [heartbeats, setHeartbeats] = useState<Heartbeat[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const run = async () => {
      try {
        const token = adminToken();
        const res = await fetch(`${baseUrl}/health/heartbeats`, {
          cache: "no-store",
        });
        const data = await res.json();
        setHeartbeats(data.heartbeats || []);
      } finally {
        setLoading(false);
      }
    };
    run();
  }, []);

  const computed = useMemo(() => {
    const now = Date.now();
    return heartbeats.map((hb) => {
      const seconds = Math.floor((now - new Date(hb.last_heartbeat_at).getTime()) / 1000);
      const derivedStatus = seconds > 60 ? "ZOMBIE" : "ACTIVE";
      return { ...hb, lastPulseSeconds: seconds, derivedStatus };
    });
  }, [heartbeats]);

  return (
    <div className="flex flex-col gap-8 p-8">
      <PageHeader
        title="System Health"
        description="Live heartbeat monitor for background jobs"
      />

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Activity className="h-4 w-4" />
            Job Heartbeats
          </CardTitle>
        </CardHeader>
        <CardContent>
          {loading ? (
            <p className="text-muted-foreground">Loading...</p>
          ) : computed.length === 0 ? (
            <p className="text-muted-foreground">No heartbeat records found.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="py-2 text-left">Job</th>
                    <th className="py-2 text-left">Last Pulse</th>
                    <th className="py-2 text-left">Expected Freq</th>
                    <th className="py-2 text-left">Derived</th>
                  </tr>
                </thead>
                <tbody>
                  {computed.map((hb) => (
                    <tr key={hb.job_name} className="border-b">
                      <td className="py-2">{hb.job_name}</td>
                      <td className="py-2">{hb.lastPulseSeconds}s ago</td>
                      <td className="py-2">{hb.expected_frequency_sec}s</td>
                      <td className="py-2">
                        <Badge
                          className={
                            hb.derivedStatus === "ZOMBIE"
                              ? "bg-red-100 text-red-700"
                              : "bg-green-100 text-green-700"
                          }
                        >
                          {hb.derivedStatus}
                        </Badge>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
