"use client";

import { useEffect, useState } from 'react';
import { Activity, AlertCircle, CheckCircle, Server } from 'lucide-react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import StatCard from '@/components/StatCard';
import { PageHeader } from '@/components/page-header';

const baseUrl = 'http://localhost:8080';

type HealthStatus = {
  status?: 'ok' | 'error' | string;
  uptime?: string | number;
  timestamp?: string;
  [key: string]: unknown;
};

type JobsStatus = {
  running?: boolean;
  [key: string]: unknown;
};

export default function AdminDashboard() {
  const [stats, setStats] = useState<{
    health: HealthStatus | null;
    jobs: JobsStatus | null;
    alerts: unknown | null;
  }>({
    health: null,
    jobs: null,
    alerts: null,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        // Fetch health status
        const healthRes = await fetch(`${baseUrl}/`);
        const healthData = await healthRes.json();
        setStats((prev) => ({ ...prev, health: healthData }));

        // Fetch job status
        try {
          const jobsRes = await fetch(`${baseUrl}/health/jobs`);
          const jobsData = await jobsRes.json();
          setStats((prev) => ({ ...prev, jobs: jobsData }));
        } catch (e) {
          console.log('Could not fetch jobs');
        }
      } catch (error) {
        console.error('Error fetching stats:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
    const interval = setInterval(fetchStats, 5000);
    return () => clearInterval(interval);
  }, []);

  const getHealthStatus = () => {
    if (!stats.health) return 'unknown';
    return stats.health.status === 'ok' ? 'Healthy' : 'Unhealthy';
  };

  const getHealthColor = () => {
    if (!stats.health) return 'default';
    return stats.health.status === 'ok' ? 'default' : 'error';
  };

  return (
    <div className="flex flex-col gap-8 p-8">
      <PageHeader 
        title="Operational Overview" 
        description="Monitor system health and performance metrics"
      />

      {loading ? (
        <div className="flex items-center justify-center h-96">
          <div className="text-center">
            <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-muted-foreground">Loading dashboard...</p>
          </div>
        </div>
      ) : (
        <>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <StatCard
              title="API Status"
              value={getHealthStatus()}
              icon={Server}
              description="Backend API health"
            />
            <StatCard
              title="Scheduler Status"
              value={stats.jobs?.running ? 'Active' : 'Inactive'}
              icon={Activity}
              description="Job scheduler status"
            />
            <StatCard
              title="Uptime"
              value={stats.health?.uptime || '-'}
              icon={CheckCircle}
              description="System uptime"
            />
            <StatCard
              title="Last Check"
              value={stats.health?.timestamp 
                ? new Date(stats.health.timestamp).toLocaleTimeString()
                : '-'
              }
              icon={AlertCircle}
              description="Last health check"
            />
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>System Information</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex justify-between items-center border-b pb-2">
                  <span className="text-sm text-muted-foreground">API Server</span>
                  <span className="font-semibold">{baseUrl}</span>
                </div>
                <div className="flex justify-between items-center border-b pb-2">
                  <span className="text-sm text-muted-foreground">Environment</span>
                  <span className="font-semibold">Development</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Last Updated</span>
                  <span className="font-semibold">
                    {stats.health?.timestamp
                      ? new Date(stats.health.timestamp).toLocaleString()
                      : '-'}
                  </span>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>API Health</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-muted-foreground">Status</span>
                    <Badge variant={getHealthColor()}>
                      {getHealthStatus()}
                    </Badge>
                  </div>
                  <div className="pt-4 border-t">
                    <p className="text-sm font-medium mb-2">Details</p>
                    <pre className="bg-muted p-2 rounded text-xs overflow-auto max-h-40">
                      {stats.health ? JSON.stringify(stats.health, null, 2) : 'No data'}
                    </pre>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {stats.jobs && (
            <Card>
              <CardHeader>
                <CardTitle>Job Scheduler Status</CardTitle>
              </CardHeader>
              <CardContent>
                <pre className="bg-muted p-4 rounded text-sm overflow-auto">
                  {JSON.stringify(stats.jobs, null, 2)}
                </pre>
              </CardContent>
            </Card>
          )}
        </>
      )}
    </div>
  );
}
