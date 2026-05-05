'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, AlertCircle, Settings, BarChart3, Clock, Truck, LucideIcon } from 'lucide-react';
import { useAdminAuth } from '@/lib/admin-auth';

interface Tab {
  id: string;
  label: string;
  icon: LucideIcon;
  href: string;
}

export default function Sidebar() {
  const pathname = usePathname();
  const { signOut } = useAdminAuth();

  const tabs: Tab[] = [
    { id: 'dashboard', label: 'Dashboard', icon: Home, href: '/admin' },
    { id: 'alerts', label: 'Alert Rules', icon: AlertCircle, href: '/admin/alerts' },
    { id: 'vehicles', label: 'Vehicle Verification', icon: Truck, href: '/admin/vehicles' },
    { id: 'health', label: 'System Health', icon: BarChart3, href: '/admin/health' },
    { id: 'scheduler', label: 'Scheduler', icon: Clock, href: '/admin/scheduler' },
    { id: 'settings', label: 'Settings', icon: Settings, href: '/admin/settings' },
  ];

  const isActive = (href: string) => {
    if (href === '/admin') return pathname === '/admin';
    return pathname.startsWith(href);
  };

  return (
    <aside className="w-64 bg-safe-slate text-cloud-white h-screen fixed left-0 top-0 shadow-xl flex flex-col">
      <div className="p-6 border-b border-gray-600">
        <h1 className="text-2xl font-bold flex items-center gap-2">
          <div className="w-8 h-8 bg-transit-teal rounded-lg flex items-center justify-center">
            📦
          </div>
          <span className="text-cloud-white">DropCity</span>
        </h1>
      </div>

      <nav className="mt-6 flex-1">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const active = isActive(tab.href);
          return (
            <Link
              key={tab.id}
              href={tab.href}
              className={`block w-full px-6 py-3 flex items-center gap-3 transition duration-200 ${
                active ? 'bg-transit-teal border-l-4 border-alert-amber' : 'hover:bg-gray-700'
              }`}
            >
              <Icon size={20} />
              <span className="font-medium">{tab.label}</span>
            </Link>
          );
        })}
      </nav>

      <div className="px-6 py-4 border-t border-gray-600">
        <div className="text-sm text-gray-300">
          <p className="font-semibold text-cloud-white mb-1">Status</p>
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 bg-heartbeat-active rounded-full animate-pulse"></div>
            <span>Connected</span>
          </div>
          <button
            type="button"
            onClick={() => signOut()}
            className="mt-3 text-xs text-red-300 hover:text-red-200"
          >
            Sign out
          </button>
        </div>
      </div>
    </aside>
  );
}
