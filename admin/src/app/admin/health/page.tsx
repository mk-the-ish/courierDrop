"use client";

import { useEffect, useMemo, useState } from "react";
import { Activity } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import StatCard from "@/components/StatCard";
import { getApiBaseUrl } from "@/lib/api-base-url";

const baseUrl = getApiBaseUrl();

type Heartbeat = {
  job_name: string;
  last_heartbeat_at: string;
  expected_frequency_sec: number;
  status: string;
};

export default function HealthPage() {
  const [heartbeats, setHeartbeats] = useState<Heartbeat[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const run = async () => {
      try {
        const res = await fetch(`${baseUrl}/health/heartbeats`, { cache: "no-store" });
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

  const activeCount = computed.filter((hb) => hb.derivedStatus === "ACTIVE").length;

  return (
    <div className="space-y-6">
      <PageHeader
        title="System Health"
        description="A compact heartbeat monitor for background jobs and service liveness."
      />

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard title="Jobs Monitored" value={computed.length} icon={Activity} color="teal" />
        <StatCard title="Active" value={activeCount} icon={Activity} color="green" />
        <StatCard title="Stale" value={computed.length - activeCount} icon={Activity} color="red" />
      </div>

      <Card>
        <CardHeader>
          <p className="micro-label">Heartbeat Table</p>
          <CardTitle>Job Pulse Status</CardTitle>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">
              Loading heartbeat records...
            </div>
          ) : computed.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">
              No heartbeat records found.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-white/10 text-left">
                    <th className="py-3 pr-4 font-medium text-slate-400">Job</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Last Pulse</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Expected Freq</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {computed.map((hb) => (
                    <tr key={hb.job_name} className="border-b border-white/5 hover:bg-white/5">
                      <td className="py-3 pr-4 text-slate-100">{hb.job_name}</td>
                      <td className="py-3 pr-4 text-slate-300">{hb.lastPulseSeconds}s ago</td>
                      <td className="py-3 pr-4 text-slate-300">{hb.expected_frequency_sec}s</td>
                      <td className="py-3 pr-4">
                        <Badge variant={hb.derivedStatus === "ZOMBIE" ? "error" : "success"}>
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
