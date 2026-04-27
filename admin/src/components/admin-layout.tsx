'use client';

import { usePathname } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';
import Sidebar from './Sidebar.tsx';
import ProtectedRoute from './protected-route';

// Pages that don't require authentication (auth pages)
const publicPages = ['/login', '/forgot-password', '/reset-password'];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { loading } = useAuth();
  const isPublicPage = publicPages.includes(pathname);

  // For auth pages, render without sidebar
  if (isPublicPage) {
    return <>{children}</>;
  }

  // Show minimal loading state for protected pages during auth check
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-teal-500"></div>
      </div>
    );
  }

  // For protected pages, wrap with ProtectedRoute and show sidebar
  return (
    <ProtectedRoute>
      <div className="flex min-h-screen bg-cloud-white">
        <Sidebar />
        <main className="flex-1 ml-64 p-8">
          <div className="max-w-7xl mx-auto">
            {children}
          </div>
        </main>
      </div>
    </ProtectedRoute>
  );
}
