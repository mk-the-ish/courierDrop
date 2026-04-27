'use client';

import { usePathname } from 'next/navigation';
import Sidebar from './Sidebar.tsx';
import ProtectedRoute from './protected-route';

// Pages that don't require authentication (auth pages)
const publicPages = ['/login', '/forgot-password', '/reset-password'];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const isPublicPage = publicPages.includes(pathname);

  // For auth pages, render without sidebar
  if (isPublicPage) {
    return <>{children}</>;
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
