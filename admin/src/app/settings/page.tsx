'use client';

import DashboardHeader from '@/components/DashboardHeader.tsx';
import { Settings } from 'lucide-react';

export default function SettingsPage() {
  return (
    <div className="space-y-8">
      <DashboardHeader
        title="Settings"
        subtitle="Configure system settings and preferences"
        actions={null}
      />

      <div className="card p-8">
        <div className="flex flex-col items-center justify-center py-12">
          <Settings size={48} className="text-safe-slate mb-4" />
          <h2 className="text-2xl font-bold text-safe-slate mb-2">Settings</h2>
          <p className="text-gray-600">Settings panel coming soon</p>
        </div>
      </div>
    </div>
  );
}
