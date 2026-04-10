'use client';

import { useEffect, useState } from 'react';
import DashboardHeader from '@/components/DashboardHeader.tsx';
import HeartbeatVisualization from '@/components/HeartbeatVisualization.tsx';
import { apiClient } from '@/lib/api-client';
import { BarChart3 } from 'lucide-react';

interface Heartbeat {
  id: string;
  name: string;
  state: 'active' | 'missed' | 'alert';
  lastUpdate: string;
}

export default function HealthPage() {
  const [heartbeats, setHeartbeats] = useState<Heartbeat[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchHealthData = async () => {
      try {
        setLoading(true);
        setError(null);
        const data = await apiClient.getHeartbeats();
        setHeartbeats(Array.isArray(data) ? data : []);
      } catch (err) {
        console.error('Failed to fetch health data:', err);
        setError('Failed to load system health data.');
      } finally {
        setLoading(false);
      }
    };

    fetchHealthData();

    // Refresh every 10 seconds
    const interval = setInterval(fetchHealthData, 10000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="space-y-8">
        <DashboardHeader
          title="System Health"
          subtitle="Loading..."
          actions={null}
        />
        <div className="text-center py-12">
          <p className="text-gray-600">Fetching system health status...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <DashboardHeader
        title="System Health"
        subtitle="Monitor system components and services"
        actions={null}
      />

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      )}

      {heartbeats.length > 0 ? (
        <HeartbeatVisualization items={heartbeats} title="System Components" />
      ) : (
        <div className="card p-8">
          <div className="flex flex-col items-center justify-center py-12">
            <BarChart3 size={48} className="text-transit-teal mb-4" />
            <h2 className="text-2xl font-bold text-safe-slate mb-2">No Health Data Available</h2>
            <p className="text-gray-600">Unable to retrieve system health information from the backend.</p>
          </div>
        </div>
      )}
    </div>
  );
}
