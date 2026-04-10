'use client';

import { useEffect, useState } from 'react';
import DashboardHeader from '@/components/DashboardHeader';
import StatCard from '@/components/StatCard';
import HeartbeatVisualization from '@/components/HeartbeatVisualization';
import { Activity, Briefcase, Clock, Users, Server } from 'lucide-react';

const mockCouriers = [
  { id: 'COUR-001', name: 'Alex Johnson', status: 'on-duty' },
  { id: 'COUR-002', name: 'Maria Garcia', status: 'on-duty' },
  { id: 'COUR-003', name: 'Chen Wei', status: 'off-duty' },
];

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

const getCourierName = (courierId: string | null) => {
  if (!courierId) return 'N/A';
  const courier = mockCouriers.find((c) => c.id === courierId);
  return courier ? courier.name : 'N/A';
};

export default function Dashboard() {
  const [mockJobs, setMockJobs] = useState([
    { id: 'JOB-9871', status: 'in-progress', courierId: 'COUR-001', lastReportedAt: '' },
    { id: 'JOB-9872', status: 'pending', courierId: null, lastReportedAt: '' },
    { id: 'JOB-9873', status: 'completed', courierId: 'COUR-003', lastReportedAt: '' },
    { id: 'JOB-9874', status: 'in-progress', courierId: 'COUR-002', lastReportedAt: '' },
    { id: 'JOB-9875', status: 'pending', courierId: null, lastReportedAt: '' },
  ]);

  const [heartbeatItems, setHeartbeatItems] = useState([
    { id: 'api', name: 'API Server', state: 'active' as const, lastUpdate: '' },
    { id: 'db', name: 'Database', state: 'active' as const, lastUpdate: '' },
    { id: 'scheduler', name: 'Job Scheduler', state: 'missed' as const, lastUpdate: '' },
  ]);

  const [currentTime, setCurrentTime] = useState('');

  useEffect(() => {
    const now = new Date();
    setCurrentTime(now.toLocaleString());

    setMockJobs([
      { id: 'JOB-9871', status: 'in-progress', courierId: 'COUR-001', lastReportedAt: new Date(Date.now() - 60000).toLocaleString() },
      { id: 'JOB-9872', status: 'pending', courierId: null, lastReportedAt: new Date(Date.now() - 3600000).toLocaleString() },
      { id: 'JOB-9873', status: 'completed', courierId: 'COUR-003', lastReportedAt: new Date(Date.now() - 7200000).toLocaleString() },
      { id: 'JOB-9874', status: 'in-progress', courierId: 'COUR-002', lastReportedAt: new Date(Date.now() - 120000).toLocaleString() },
      { id: 'JOB-9875', status: 'pending', courierId: null, lastReportedAt: new Date(Date.now() - 1800000).toLocaleString() },
    ]);

    setHeartbeatItems([
      { id: 'api', name: 'API Server', state: 'active' as const, lastUpdate: new Date().toLocaleTimeString() },
      { id: 'db', name: 'Database', state: 'active' as const, lastUpdate: new Date().toLocaleTimeString() },
      { id: 'scheduler', name: 'Job Scheduler', state: 'missed' as const, lastUpdate: new Date(Date.now() - 30000).toLocaleTimeString() },
    ]);
  }, []);

  const activeJobs = mockJobs.filter((j) => j.status === 'in-progress').length;
  const pendingJobs = mockJobs.filter((j) => j.status === 'pending').length;
  const onlineCouriers = mockCouriers.filter((c) => c.status === 'on-duty').length;

  return (
    <div className="space-y-8">
      <DashboardHeader
        title="Operational Dashboard"
        subtitle="Welcome to DropCity Admin Panel"
      />

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="API Status"
          value="Running"
          icon={Server}
          color="teal"
          description="Server health status"
        />
        <StatCard
          title="Active Jobs"
          value={activeJobs}
          icon={Briefcase}
          color="teal"
          description="Jobs currently in progress"
        />
        <StatCard
          title="Pending Matches"
          value={pendingJobs}
          icon={Clock}
          color="amber"
          description="Jobs awaiting courier assignment"
        />
        <StatCard
          title="Couriers Online"
          value={onlineCouriers}
          icon={Users}
          color="slate"
          description="Couriers currently on-duty"
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
                {mockJobs.map((job) => (
                  <tr key={job.id} className="border-b border-slate-100 hover:bg-slate-50">
                    <td className="py-3 px-2 font-medium text-slate-900">{job.id}</td>
                    <td className="py-3 px-2">
                      <span className={`px-3 py-1 rounded-full text-xs font-semibold ${getStatusVariant(job.status)}`}>
                        {job.status}
                      </span>
                    </td>
                    <td className="py-3 px-2 text-slate-600">{getCourierName(job.courierId)}</td>
                    <td className="py-3 px-2 text-slate-600">{job.lastReportedAt}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="card p-6">
          <h3 className="text-lg font-bold text-safe-slate mb-4">System Information</h3>
          <div className="space-y-3">
            <div className="flex justify-between items-center py-2 border-b border-slate-200">
              <span className="text-slate-600">API Server</span>
              <span className="font-semibold text-slate-900">http://localhost:8080</span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-slate-200">
              <span className="text-slate-600">Environment</span>
              <span className="font-semibold text-slate-900">Development</span>
            </div>
            <div className="flex justify-between items-center py-2 border-b border-slate-200">
              <span className="text-slate-600">Last Updated</span>
              <span className="font-semibold text-slate-900">{new Date().toLocaleString()}</span>
            </div>
          </div>
        </div>
      </div>

      <HeartbeatVisualization items={heartbeatItems} title="System Heartbeat" />
    </div>
  );
}
