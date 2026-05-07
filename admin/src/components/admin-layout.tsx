'use client';

import { useEffect } from "react";
import { usePathname, useRouter } from "next/navigation";
import Sidebar from './Sidebar.tsx';
import { useAdminAuth } from "@/lib/admin-auth";
import NotificationBell from "./NotificationBell";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { user, loading } = useAdminAuth();

  const authPages = ["/login", "/forgot-password", "/reset-password"];
  const isAuthPage = authPages.some((page) => pathname?.startsWith(page));
  const isAdminPage = pathname?.startsWith("/admin");

  useEffect(() => {
    if (loading) return;
    if (isAdminPage && !user) {
      router.replace("/login");
      return;
    }
    if (isAuthPage && user) {
      router.replace("/admin");
    }
  }, [isAdminPage, isAuthPage, loading, router, user]);

  if (loading && isAdminPage) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-cloud-white">
        <p className="text-slate-500">Checking session...</p>
      </div>
    );
  }

  if (isAuthPage) {
    return <>{children}</>;
  }

  return (
    <div className="flex min-h-screen bg-cloud-white">
      <Sidebar />
      <main className="flex-1 ml-64 p-8">
        <div className="max-w-7xl mx-auto">
          <div className="mb-4 flex justify-end">
            <NotificationBell />
          </div>
          {children}
        </div>
      </main>
    </div>
  );
}
