'use client';

import React, { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Activity,
  AlertCircle,
  BarChart3,
  Clock,
  MapPinned,
  Scale,
  Settings,
  ScrollText,
  Truck,
  Users,
  Home,
  LucideIcon,
  ShieldCheck,
} from 'lucide-react';
import { useAdminAuth } from '@/lib/admin-auth';

interface Tab {
  id: string;
  label: string;
  icon: LucideIcon;
  href: string;
}

function formatUtcClock(date: Date) {
  return date.toISOString().slice(11, 19) + ' UTC';
}

export default function Sidebar() {
  const pathname = usePathname();
  const { signOut, user } = useAdminAuth();
  const [clock, setClock] = useState(() => formatUtcClock(new Date()));

  useEffect(() => {
    const timer = window.setInterval(() => setClock(formatUtcClock(new Date())), 1000);
    return () => window.clearInterval(timer);
  }, []);

  const tabs: Tab[] = useMemo(
    () => [
      { id: 'dashboard', label: 'Dashboard', icon: Home, href: '/admin' },
      { id: 'monitoring', label: 'Monitoring Console', icon: Activity, href: '/admin/monitoring' },
      { id: 'couriers', label: 'Couriers & Vehicles', icon: Users, href: '/admin/couriers' },
      { id: 'disputes', label: 'Disputes Workspace', icon: Scale, href: '/admin/disputes' },
      { id: 'spatial', label: 'Spatial & Pricing', icon: MapPinned, href: '/admin/spatial-analytics' },
      { id: 'health', label: 'Health & Scheduler', icon: Clock, href: '/admin/health' },
      { id: 'alerts', label: 'Alert Rules', icon: AlertCircle, href: '/admin/alerts' },
      { id: 'logs', label: 'Logs', icon: ScrollText, href: '/admin/logs' },
      { id: 'vehicles', label: 'Vehicle Verification', icon: Truck, href: '/admin/vehicles' },
      { id: 'settings', label: 'Settings', icon: Settings, href: '/admin/settings' },
    ],
    []
  );

  const isActive = (href: string) => {
    if (href === '/admin') return pathname === '/admin';
    return pathname.startsWith(href);
  };

  return (
    <aside className="fixed left-0 top-0 flex h-screen w-72 flex-col border-r border-white/10 bg-slate-950/90 text-slate-100 backdrop-blur-xl">
      <div className="border-b border-white/10 px-6 py-6">
        <div className="flex items-center gap-3">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-orange-accent text-lg font-black text-white shadow-[0_16px_30px_-16px_rgba(255,107,53,0.85)]">
            D
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-lg font-semibold text-slate-50">DropCity</h1>
              <span className="rounded-full border border-orange-accent/30 bg-orange-accent/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.2em] text-orange-300">
                Admin
              </span>
            </div>
            <p className="text-xs uppercase tracking-[0.28em] text-slate-500">Logistics Control</p>
          </div>
        </div>

        <div className="mt-5 rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-slate-300">
          <div className="flex items-center gap-2">
            <ShieldCheck size={16} className="text-emerald-300" />
            <span className="truncate">{user?.email ?? 'simonmkaro@gmail.com'}</span>
          </div>
        </div>
      </div>

      <nav className="flex-1 space-y-2 overflow-y-auto px-3 py-4">
        <p className="px-3 pb-2 text-[10px] font-semibold uppercase tracking-[0.28em] text-slate-500">
          Central Operations
        </p>
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const active = isActive(tab.href);
          return (
            <Link
              key={tab.id}
              href={tab.href}
              className={`group flex items-center gap-3 rounded-2xl border px-4 py-3 text-sm transition ${
                active
                  ? 'border-orange-accent/40 bg-orange-accent/10 text-orange-200 shadow-[0_12px_28px_-20px_rgba(255,107,53,0.75)]'
                  : 'border-transparent text-slate-400 hover:border-white/10 hover:bg-white/5 hover:text-slate-100'
              }`}
            >
              <Icon size={18} className={active ? 'text-orange-300' : 'text-slate-500 group-hover:text-slate-200'} />
              <span className="font-medium">{tab.label}</span>
            </Link>
          );
        })}
      </nav>

      <div className="border-t border-white/10 px-4 py-4">
        <div className="mt-4 flex items-center justify-between text-xs text-slate-500">
          <div>
            <p className="uppercase tracking-[0.22em]">System State</p>
            <div className="mt-1 flex items-center gap-2 text-slate-300">
              <span className="h-2 w-2 rounded-full bg-emerald-400 shadow-[0_0_12px_rgba(52,211,153,0.75)]" />
              LIVE
            </div>
          </div>
          <div className="text-right">
            <p className="uppercase tracking-[0.22em]">UTC Clock</p>
            <p className="mt-1 font-mono text-slate-300">{clock}</p>
          </div>
        </div>

        <button
          type="button"
          onClick={() => signOut()}
          className="mt-4 flex w-full items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-slate-200 transition hover:bg-white/10"
        >
          <Activity size={16} />
          Sign out
        </button>
      </div>
    </aside>
  );
}
