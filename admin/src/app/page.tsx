'use client';

import { useEffect, useState } from 'react';
import DashboardHeader from '@/components/DashboardHeader.tsx';
import StatCard from '@/components/StatCard.tsx';
import HeartbeatVisualization from '@/components/HeartbeatVisualization.tsx';
import { apiClient } from '@/lib/api-client';
import { Activity, Briefcase, Clock, Users, Server } from 'lucide-react';

interface Job {
  id: string;
  status: 'in-progress' | 'pending' | 'completed' | 'cancelled';
  courierId?: string;
  courierName?: string;
  lastReportedAt: string;
}

interface Courier {
  id: string;
  name: string;
  status: 'on-duty' | 'off-duty';
}

interface Heartbeat {
  id: string;
  name: string;
  state: 'active' | 'missed' | 'alert';
  lastUpdate: string;
}

const getStatusVariant = (status: string) => {
  switch (status) {
    case 'completed':
      return 'bg-green-100 text-green-800';
    case 'in-progress':
      return 'bg-blue-100 text-blue-800';
    case 'pending':
      return 'bg-yellow-100 text-yellow-800';
    case 'cancelled':
      return 'bg-red-100 text-red-800';
    default:
      return 'bg-slate-100 text-slate-800';
  }
};

export default function Dashboard() {
  const [jobs, setJobs] = useState<Job[]>([]);
  const [couriers, setCouriers] = useState<Courier[]>([]);
  const [heartbeats, setHeartbeats] = useState<Heartbeat[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        setLoading(true);
        setError(null);

        // Fetch data from backend
        const [jobsData, couriersData, heartbeatData] = await Promise.all([
          apiClient.getJobs().catch(() => []),
          apiClient.getCouriers().catch(() => []),
          apiClient.getHeartbeats().catch(() => []),
        ]);

        setJobs(Array.isArray(jobsData) ? jobsData : []);
        setCouriers(Array.isArray(couriersData) ? couriersData : []);
        setHeartbeats(Array.isArray(heartbeatData) ? heartbeatData : []);
      } catch (err) {
        console.error('Failed to fetch dashboard data:', err);
        setError('Failed to load dashboard data. Backend may be offline.');
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardData();

    // Refresh data every 30 seconds
    const interval = setInterval(fetchDashboardData, 30000);
    return () => clearInterval(interval);
  }, []);

  const activeJobs = jobs.filter((j) => j.status === 'in-progress').length;
  const pendingJobs = jobs.filter((j) => j.status === 'pending').length;
  const onlineCouriers = couriers.filter((c) => c.status === 'on-duty').length;

  if (loading) {
    return (
      <div className="space-y-8">
        <DashboardHeader
          title="Operational Dashboard"
          subtitle="Loading..."
          actions={null}
        />
        <div className="text-center py-12">
          <p className="text-gray-600">Fetching data from backend...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <DashboardHeader
        title="Operational Dashboard"
        subtitle="Welcome to DropCity Admin Panel"
        actions={null}
      />

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="API Status"
          value="Running"
          icon={Server}
          color="teal"
          description="Server health status"
          trend={0}
        />
        <StatCard
          title="Active Jobs"
          value={activeJobs}
          icon={Briefcase}
          color="teal"
          description="Jobs currently in progress"
          trend={0}
        />
        <StatCard
          title="Pending Matches"
          value={pendingJobs}
          icon={Clock}
          color="amber"
          description="Jobs awaiting courier assignment"
          trend={0}
        />
        <StatCard
          title="Couriers Online"
          value={onlineCouriers}
          icon={Users}
          color="slate"
          description="Couriers currently on-duty"
          trend={0}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <div className="card p-6">
          <h3 className="text-lg font-bold text-safe-slate mb-6 flex items-center gap-2">
            <Activity size={20} />
            Recent Job Activity
          </h3>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-200">
                  <th className="text-left py-2 px-2 font-semibold text-slate-600">Job ID</th>
                  <th className="text-left py-2 px-2 font-semibold text-slate-600">Status</th>
                  <th className="text-left py-2 px-2 font-semibold text-slate-600">Courier</th>
                  <th className="text-left py-2 px-2 font-semibold text-slate-600">Last Update</th>
                </tr>
              </thead>
              <tbody>
                {jobs.length > 0 ? (
                  jobs.map((job) => (
                    <tr key={job.id} className="border-b border-slate-100 hover:bg-slate-50">
                      <td className="py-3 px-2 font-medium text-slate-900">{job.id}</td>
                      <td className="py-3 px-2">
                        <span className={`px-3 py-1 rounded-full text-xs font-semibold ${getStatusVariant(job.status)}`}>
                          {job.status}
                        </span>
                      </td>
                      <td className="py-3 px-2 text-slate-600">{job.courierName || 'N/A'}</td>
                      <td className="py-3 px-2 text-slate-600">{job.lastReportedAt}</td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={4} className="py-8 text-center text-gray-600">
                      No jobs found
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

        <div className="card p-6">
          <h3 className="text-lg font-bold text-safe-slate mb-4">System Information</h3>
          <div className="space-y-3">
            <div className="flex justify-between items-center py-2 border-b border-slate-200">
              <span className="text-slate-600">API Server</span>
              <span className="font-semibold text-slate-900">{process.env.NEXT_PUBLIC_API_URL}</span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-slate-200">
              <span className="text-slate-600">Environment</span>
              <span className="font-semibold text-slate-900">Production</span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-slate-200">
              <span className="text-slate-600">Couriers Online</span>
              <span className="font-semibold text-slate-900">{onlineCouriers} / {couriers.length}</span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-slate-200">
              <span className="text-slate-600">Total Jobs</span>
              <span className="font-semibold text-slate-900">{jobs.length}</span>
            </div>
          </div>
        </div>
      </div>

      {heartbeats.length > 0 && <HeartbeatVisualization items={heartbeats} title="System Heartbeat" />}
    </div>
  );
}
