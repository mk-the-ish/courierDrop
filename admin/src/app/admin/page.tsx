"use client";

import { useEffect, useMemo, useState } from "react";
import { Activity, AlertCircle, CheckCircle, Server, Shield, Clock3, Sparkles } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import StatCard from "@/components/StatCard";
import { PageHeader } from "@/components/page-header";
import { getApiBaseUrl } from "@/lib/api-base-url";

const baseUrl = getApiBaseUrl();

type HealthStatus = {
  status?: "ok" | "error" | string;
  uptime?: string | number;
  timestamp?: string;
  [key: string]: unknown;
};

type JobsStatus = {
  schedulerRunning?: boolean;
  running?: boolean;
  jobs?: Array<{ name?: string; status?: string; lastRun?: string | null }>;
  [key: string]: unknown;
};

function formatTimestamp(value?: string) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return new Intl.DateTimeFormat("en-ZA", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

export default function AdminDashboard() {
  const [stats, setStats] = useState<{
    health: HealthStatus | null;
    jobs: JobsStatus | null;
  }>({
    health: null,
    jobs: null,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const healthRes = await fetch(`${baseUrl}/`);
        const healthData = await healthRes.json();
        setStats((prev) => ({ ...prev, health: healthData }));

        try {
          const jobsRes = await fetch(`${baseUrl}/health/jobs`);
          const jobsData = await jobsRes.json();
          setStats((prev) => ({ ...prev, jobs: jobsData }));
        } catch (error) {
          console.log("Could not fetch jobs", error);
        }
      } catch (error) {
        console.error("Error fetching stats:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
    const interval = setInterval(fetchStats, 5000);
    return () => clearInterval(interval);
  }, []);

  const schedulerIsActive = Boolean(stats.jobs?.schedulerRunning ?? stats.jobs?.running);
  const healthStatus = stats.health?.status === "ok" ? "Healthy" : stats.health ? "Attention" : "Unknown";
  const healthBadge: "success" | "warning" | "secondary" = stats.health?.status === "ok"
    ? "success"
    : stats.health
      ? "warning"
      : "secondary";
  const recentJobs = useMemo(() => (stats.jobs?.jobs ?? []).slice(0, 3), [stats.jobs]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Central Scheduler & Diagnostics Console"
        description="Compact operational overview for backend health, queue activity, and live service posture."
        action={
          <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-2 text-xs font-medium text-slate-300">
            <span className="mr-2 inline-flex h-2 w-2 rounded-full bg-emerald-400 shadow-[0_0_12px_rgba(74,222,128,0.8)]" />
            Live diagnostics
          </div>
        }
      />

      {loading ? (
        <div className="flex min-h-[420px] items-center justify-center">
          <div className="rounded-2xl border border-white/10 bg-white/5 px-6 py-4 text-sm text-slate-300">
            Loading dashboard...
          </div>
        </div>
      ) : (
        <>
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <StatCard
              title="API Status"
              value={healthStatus}
              icon={Server}
              description="Backend gateway and service reachability"
              color="amber"
            />
            <StatCard
              title="Scheduler Status"
              value={schedulerIsActive ? "Active" : "Idle"}
              icon={Activity}
              description="Background job runtime"
              color={schedulerIsActive ? "green" : "slate"}
            />
            <StatCard
              title="Uptime"
              value={stats.health?.uptime || "-"}
              icon={CheckCircle}
              description="Health response uptime"
              color="teal"
            />
            <StatCard
              title="Last Check"
              value={formatTimestamp(stats.health?.timestamp)}
              icon={Clock3}
              description="Most recent health sample"
              color="slate"
            />
          </div>

          <div className="grid gap-4 xl:grid-cols-[1.15fr_0.85fr]">
            <Card>
              <CardHeader className="flex flex-row items-start justify-between gap-4">
                <div>
                  <p className="micro-label">Runtime Snapshot</p>
                  <CardTitle>System Information</CardTitle>
                </div>
                <Badge variant={healthBadge}>{healthStatus}</Badge>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid gap-3 md:grid-cols-2">
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <div className="micro-label mb-2">API Server</div>
                    <p className="break-all text-sm text-slate-200">{baseUrl}</p>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <div className="micro-label mb-2">Environment</div>
                    <p className="text-sm text-slate-200">Development</p>
                  </div>
                </div>
                <div className="rounded-2xl border border-white/10 bg-slate-950/60 p-4">
                  <div className="flex items-center justify-between gap-4">
                    <div>
                      <div className="micro-label mb-2">Raw Health Payload</div>
                      <p className="text-sm text-slate-400">
                        Lightweight JSON snapshot from the core API endpoint.
                      </p>
                    </div>
                    <Shield size={18} className="text-orange-accent" />
                  </div>
                  <pre className="mt-4 max-h-64 overflow-auto rounded-2xl border border-white/10 bg-black/30 p-4 text-xs text-slate-300">
                    {stats.health ? JSON.stringify(stats.health, null, 2) : "No data"}
                  </pre>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <p className="micro-label">Live Queue</p>
                <CardTitle className="flex items-center gap-2">
                  <Sparkles size={16} className="text-orange-accent" />
                  Job Scheduler Status
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-slate-400">Scheduler engine</span>
                    <Badge variant={schedulerIsActive ? "success" : "secondary"}>
                      {schedulerIsActive ? "Running" : "Paused"}
                    </Badge>
                  </div>
                </div>

                <div className="space-y-3">
                  {recentJobs.length > 0 ? (
                    recentJobs.map((job, index) => (
                      <div key={`${job.name || "job"}-${index}`} className="rounded-2xl border border-white/10 bg-slate-950/60 p-4">
                        <div className="flex items-center justify-between gap-4">
                          <div>
                            <p className="text-sm font-semibold text-slate-100">{job.name || "Untitled job"}</p>
                            <p className="mt-1 text-xs text-slate-400">
                              Last run: {job.lastRun ? formatTimestamp(job.lastRun) : "—"}
                            </p>
                          </div>
                          <Badge variant={job.status === "running" ? "success" : "outline"}>
                            {job.status || "unknown"}
                          </Badge>
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-4 text-sm text-slate-400">
                      No scheduler jobs returned by the API yet.
                    </div>
                  )}
                </div>

                <div className="rounded-2xl border border-white/10 bg-gradient-to-r from-orange-accent/10 to-transparent p-4">
                  <div className="flex items-center gap-2">
                    <AlertCircle size={16} className="text-orange-300" />
                    <p className="text-sm font-medium text-slate-100">Operational cue</p>
                  </div>
                  <p className="mt-2 text-sm text-slate-400">
                    Keep this view dense and glanceable; it should feel like a live console, not a report page.
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        </>
      )}
    </div>
  );
}
