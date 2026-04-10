'use client';

import { Home, AlertCircle, Settings, BarChart3, Clock } from 'lucide-react';

export default function Sidebar({ activeTab, setActiveTab }) {
  const tabs = [
    { id: 'dashboard', label: 'Dashboard', icon: Home },
    { id: 'alerts', label: 'Alert Rules', icon: AlertCircle },
    { id: 'health', label: 'System Health', icon: BarChart3 },
    { id: 'scheduler', label: 'Scheduler', icon: Clock },
    { id: 'settings', label: 'Settings', icon: Settings },
  ];

  return (
    <aside className="w-64 bg-safe-slate text-cloud-white h-screen fixed left-0 top-0 shadow-xl">
      <div className="p-6 border-b border-gray-600">
        <h1 className="text-2xl font-bold flex items-center gap-2">
          <div className="w-8 h-8 bg-transit-teal rounded-lg flex items-center justify-center">
            📦
          </div>
          <span className="text-cloud-white">DropCity</span>
        </h1>
      </div>

      <nav className="mt-6">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`w-full px-6 py-3 flex items-center gap-3 transition duration-200 ${
                activeTab === tab.id
                  ? 'bg-transit-teal border-l-4 border-alert-amber'
                  : 'hover:bg-gray-700'
              }`}
            >
              <Icon size={20} />
              <span className="font-medium">{tab.label}</span>
            </button>
          );
        })}
      </nav>

      <div className="absolute bottom-0 left-0 right-0 p-6 border-t border-gray-600">
        <div className="text-sm text-gray-300">
          <p className="font-semibold text-cloud-white mb-1">Status</p>
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 bg-heartbeat-active rounded-full animate-pulse"></div>
            <span>Connected</span>
          </div>
        </div>
      </div>
    </aside>
  );
}
