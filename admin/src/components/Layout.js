import { useState } from 'react';
import Sidebar from './Sidebar';

export default function Layout({ children, activeTab, setActiveTab }) {
  return (
    <div className="flex min-h-screen bg-slate-100">
      <Sidebar activeTab={activeTab} setActiveTab={setActiveTab} />
      <main className="flex-1 ml-64 p-8">
        <div className="max-w-7xl mx-auto">
          {children}
        </div>
      </main>
    </div>
  );
}
