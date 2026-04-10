'use client';

import DashboardHeader from '@/components/DashboardHeader.tsx';
import { Clock } from 'lucide-react';

export default function SchedulerPage() {
  return (
    <div className="space-y-8">
      <DashboardHeader
        title="Scheduler"
        subtitle="Manage background jobs and scheduled tasks"
        actions={null}
      />

      <div className="card p-8">
        <div className="flex flex-col items-center justify-center py-12">
          <Clock size={48} className="text-alert-amber mb-4" />
          <h2 className="text-2xl font-bold text-safe-slate mb-2">Job Scheduler</h2>
          <p className="text-gray-600">Scheduler management coming soon</p>
        </div>
      </div>
    </div>
  );
}
