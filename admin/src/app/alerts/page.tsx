'use client';

import { useEffect, useState } from 'react';
import DashboardHeader from '@/components/DashboardHeader.tsx';
import { apiClient } from '@/lib/api-client';
import { AlertCircle } from 'lucide-react';

interface Alert {
  id: string;
  name: string;
  description: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  enabled: boolean;
  lastTriggered?: string;
}

const getSeverityColor = (severity: string) => {
  switch (severity) {
    case 'critical':
      return 'bg-red-100 text-red-800';
    case 'high':
      return 'bg-orange-100 text-orange-800';
    case 'medium':
      return 'bg-yellow-100 text-yellow-800';
    case 'low':
      return 'bg-blue-100 text-blue-800';
    default:
      return 'bg-gray-100 text-gray-800';
  }
};

export default function AlertsPage() {
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchAlerts = async () => {
      try {
        setLoading(true);
        setError(null);
        const data = await apiClient.getAlerts();
        setAlerts(Array.isArray(data) ? data : []);
      } catch (err) {
        console.error('Failed to fetch alerts:', err);
        setError('Failed to load alert rules.');
      } finally {
        setLoading(false);
      }
    };

    fetchAlerts();
  }, []);

  if (loading) {
    return (
      <div className="space-y-8">
        <DashboardHeader
          title="Alert Rules"
          subtitle="Loading..."
          actions={null}
        />
        <div className="text-center py-12">
          <p className="text-gray-600">Fetching alert rules...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <DashboardHeader
        title="Alert Rules"
        subtitle="Manage and configure system alerts"
        actions={null}
      />

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      )}

      {alerts.length > 0 ? (
        <div className="card p-6">
          <div className="grid gap-4">
            {alerts.map((alert) => (
              <div key={alert.id} className="border border-slate-200 rounded-lg p-4 hover:bg-slate-50">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <h3 className="font-bold text-safe-slate">{alert.name}</h3>
                      <span className={`px-3 py-1 rounded-full text-xs font-semibold ${getSeverityColor(alert.severity)}`}>
                        {alert.severity}
                      </span>
                      <span className={`px-3 py-1 rounded-full text-xs font-semibold ${alert.enabled ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}`}>
                        {alert.enabled ? 'Enabled' : 'Disabled'}
                      </span>
                    </div>
                    <p className="text-gray-600 text-sm">{alert.description}</p>
                    {alert.lastTriggered && (
                      <p className="text-gray-500 text-xs mt-2">Last triggered: {alert.lastTriggered}</p>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="card p-8">
          <div className="flex flex-col items-center justify-center py-12">
            <AlertCircle size={48} className="text-alert-amber mb-4" />
            <h2 className="text-2xl font-bold text-safe-slate mb-2">No Alerts</h2>
            <p className="text-gray-600">No alert rules configured yet</p>
          </div>
        </div>
      )}
    </div>
  );
}
