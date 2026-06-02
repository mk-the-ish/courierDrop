'use client';

import { useEffect } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import Sidebar from './Sidebar';
import { useAdminAuth } from '@/lib/admin-auth';
import NotificationBell from './NotificationBell';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { user, loading } = useAdminAuth();

  const authPages = ['/login', '/forgot-password', '/reset-password'];
  const publicPages = ['/terms'];
  const isAuthPage = authPages.some((page) => pathname?.startsWith(page));
  const isPublicPage = publicPages.some((page) => pathname?.startsWith(page));
  const isAdminPage = pathname?.startsWith('/admin');

  useEffect(() => {
    if (loading) return;
    if (isAdminPage && !user) {
      router.replace('/login');
      return;
    }
    if (isAuthPage && user) {
      router.replace('/admin');
    }
  }, [isAdminPage, isAuthPage, loading, router, user]);

  if (loading && isAdminPage) {
    return (
      <div className="min-h-screen bg-background">
        <div className="mx-auto flex min-h-screen max-w-7xl items-center justify-center px-6">
          <div className="rounded-2xl border border-white/10 bg-white/5 px-6 py-4 text-sm text-slate-300">
            Checking session...
          </div>
        </div>
      </div>
    );
  }

  if (isAuthPage || isPublicPage) {
    return <>{children}</>;
  }

  return (
    <div className="min-h-screen bg-background">
      <Sidebar />
      <main className="ml-72 min-h-screen">
        <div className="mx-auto flex max-w-[1600px] flex-col gap-6 px-6 py-6 lg:px-8">
          <div className="flex items-center justify-end">
            <NotificationBell />
          </div>
          {children}
        </div>
      </main>
    </div>
  );
}
