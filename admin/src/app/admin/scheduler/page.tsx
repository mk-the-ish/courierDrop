"use client";

import { useEffect, useState } from "react";
import { Clock, Play } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import StatCard from "@/components/StatCard";
import { getApiBaseUrl } from "@/lib/api-base-url";

const baseUrl = getApiBaseUrl();

function adminToken() {
  if (typeof window === "undefined") return "";
  return localStorage.getItem("admin_token") || localStorage.getItem("adminToken") || "";
}

type Job = {
  name: string;
  status: string;
  lastRun?: string | null;
  nextRun?: string | null;
  failureCount?: number;
  successCount?: number;
};

export default function SchedulerPage() {
  const [jobs, setJobs] = useState<Job[]>([]);
  const [loading, setLoading] = useState(true);
  const [triggering, setTriggering] = useState(false);

  const load = async () => {
    try {
      setLoading(true);
      const token = adminToken();
      const res = await fetch(`${baseUrl}/admin/jobs/active`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      setJobs(data.jobs || []);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const triggerMatch = async () => {
    setTriggering(true);
    try {
      const token = adminToken();
      await fetch(`${baseUrl}/admin/jobs/trigger-match-corridors`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });
      await load();
    } finally {
      setTriggering(false);
    }
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title="Job Scheduler"
        description="Monitor jobs and manually trigger corridor matching when operations need a nudge."
      />

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard title="Active Jobs" value={jobs.length} icon={Clock} color="teal" />
        <StatCard title="Running" value={jobs.filter((job) => job.status === "running").length} icon={Play} color="green" />
        <StatCard title="Paused / Idle" value={jobs.filter((job) => job.status !== "running").length} icon={Clock} color="slate" />
      </div>

      <Card>
        <CardHeader className="flex flex-row items-start justify-between gap-4">
          <div>
            <p className="micro-label">Active Queue</p>
            <CardTitle className="flex items-center gap-2">
              <Clock className="h-4 w-4" />
              Active Jobs
            </CardTitle>
          </div>
          <Button onClick={triggerMatch} disabled={triggering}>
            <Play className="mr-2 h-4 w-4" />
            {triggering ? "Triggering..." : "Trigger match_corridors()"}
          </Button>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">
              Loading jobs...
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-white/10 text-left">
                    <th className="py-3 pr-4 font-medium text-slate-400">Job</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Status</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Last Run</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Next Run</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Success/Fail</th>
                  </tr>
                </thead>
                <tbody>
                  {jobs.map((job) => (
                    <tr key={job.name} className="border-b border-white/5 hover:bg-white/5">
                      <td className="py-3 pr-4 text-slate-100">{job.name}</td>
                      <td className="py-3 pr-4">
                        <Badge variant={job.status === "running" ? "success" : "secondary"}>
                          {job.status}
                        </Badge>
                      </td>
                      <td className="py-3 pr-4 text-slate-300">{job.lastRun || "-"}</td>
                      <td className="py-3 pr-4 text-slate-300">{job.nextRun || "-"}</td>
                      <td className="py-3 pr-4 text-slate-300">
                        {(job.successCount || 0)}/{job.failureCount || 0}
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
