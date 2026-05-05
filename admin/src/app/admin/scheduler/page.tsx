"use client";

import { useEffect, useState } from "react";
import { Clock, Play } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

const baseUrl =
  process.env.NEXT_PUBLIC_API_URL || "https://dropcity-backend.onrender.com";

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
    <div className="flex flex-col gap-8 p-8">
      <PageHeader
        title="Job Scheduler"
        description="Monitor jobs and manually trigger corridor matching"
      />

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="flex items-center gap-2">
            <Clock className="h-4 w-4" />
            Active Jobs
          </CardTitle>
          <Button onClick={triggerMatch} disabled={triggering}>
            <Play className="mr-2 h-4 w-4" />
            {triggering ? "Triggering..." : "Trigger match_corridors()"}
          </Button>
        </CardHeader>
        <CardContent>
          {loading ? (
            <p className="text-muted-foreground">Loading...</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="py-2 text-left">Job</th>
                    <th className="py-2 text-left">Status</th>
                    <th className="py-2 text-left">Last Run</th>
                    <th className="py-2 text-left">Next Run</th>
                    <th className="py-2 text-left">Success/Fail</th>
                  </tr>
                </thead>
                <tbody>
                  {jobs.map((job) => (
                    <tr key={job.name} className="border-b">
                      <td className="py-2">{job.name}</td>
                      <td className="py-2">
                        <Badge>{job.status}</Badge>
                      </td>
                      <td className="py-2">{job.lastRun || "-"}</td>
                      <td className="py-2">{job.nextRun || "-"}</td>
                      <td className="py-2">
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
