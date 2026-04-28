'use client';

import Sidebar from './Sidebar.tsx';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  // Authentication deactivated - render dashboard directly
  return (
    <div className="flex min-h-screen bg-cloud-white">
      <Sidebar />
      <main className="flex-1 ml-64 p-8">
        <div className="max-w-7xl mx-auto">
          {children}
        </div>
      </main>
    </div>
  );
}
