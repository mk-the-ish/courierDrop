'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { Home, AlertCircle, Settings, BarChart3, Clock, Truck, LogOut, LucideIcon } from 'lucide-react';
import { useAuth } from '@/lib/auth-context';

interface Tab {
  id: string;
  label: string;
  icon: LucideIcon;
  href: string;
}

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { signOutUser, user } = useAuth();
  const [isSigningOut, setIsSigningOut] = React.useState(false);

  const tabs: Tab[] = [
    { id: 'dashboard', label: 'Dashboard', icon: Home, href: '/' },
    { id: 'alerts', label: 'Alert Rules', icon: AlertCircle, href: '/alerts' },
    { id: 'vehicles', label: 'Vehicle Verification', icon: Truck, href: '/vehicles' },
    { id: 'health', label: 'System Health', icon: BarChart3, href: '/health' },
    { id: 'scheduler', label: 'Scheduler', icon: Clock, href: '/scheduler' },
    { id: 'settings', label: 'Settings', icon: Settings, href: '/settings' },
  ];

  const isActive = (href: string) => {
    if (href === '/') return pathname === '/';
    return pathname.startsWith(href);
  };

  const handleSignOut = async () => {
    setIsSigningOut(true);
    try {
      await signOutUser();
      router.push('/login');
    } catch (error) {
      console.error('Sign out failed:', error);
      setIsSigningOut(false);
    }
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

      <div className="border-t border-gray-600 p-6 space-y-4">
        <div className="text-sm text-gray-300">
          <p className="font-semibold text-cloud-white mb-2">Account</p>
          <p className="text-xs text-gray-400 mb-3">{user?.email || 'Admin'}</p>
          <button
            onClick={handleSignOut}
            disabled={isSigningOut}
            className="w-full flex items-center gap-2 px-3 py-2 rounded bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            <LogOut size={16} />
            <span className="text-sm font-medium">{isSigningOut ? 'Signing out...' : 'Sign Out'}</span>
          </button>
        </div>
      </div>

      <div className="px-6 py-4 border-t border-gray-600">
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
