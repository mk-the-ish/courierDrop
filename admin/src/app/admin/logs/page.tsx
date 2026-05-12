'use client';

import { useEffect, useMemo, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { AlertCircle, Download, RefreshCw, Search } from 'lucide-react';

const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8080';

interface ErrorLogRow {
  id: string;
  device_model: string;
  os_version: string;
  stack_trace: string;
  occurred_at: string;
}

interface HandshakeLogRow {
  id: string;
  parcel_id: string;
  step: string;
  status: string;
  lat: number;
  lng: number;
  accuracy_m: number;
  created_at: string;
}

export default function LogsPage() {
  const [tab, setTab] = useState<'errors' | 'handshake'>('errors');
  const [errorLogs, setErrorLogs] = useState<ErrorLogRow[]>([]);
  const [handshakeLogs, setHandshakeLogs] = useState<HandshakeLogRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [days, setDays] = useState(7);
  const [searchTerm, setSearchTerm] = useState('');

  const getToken = () => {
    return localStorage.getItem('admin_token') || localStorage.getItem('adminToken') || '';
  };

  const loadLogs = async () => {
    setLoading(true);
    setError(null);
    try {
      const token = getToken();
      if (!token) throw new Error('Not authenticated');

      const res = await fetch(`${baseUrl}/admin/logs?limit=200&days=${days}`, {
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }
      });

      if (!res.ok) {
        if (res.status === 404) {
          setErrorLogs([]);
          setHandshakeLogs([]);
          return;
        }
        throw new Error(`Failed to load logs: ${res.status}`);
      }

      const data = await res.json();
      setErrorLogs(data.error_logs || []);
      setHandshakeLogs(data.handshake_events || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load logs');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadLogs();
  }, [days]);

  const filteredErrorLogs = useMemo(() => {
    if (!searchTerm) return errorLogs;
    return errorLogs.filter(log =>
      log.device_model.toLowerCase().includes(searchTerm.toLowerCase()) ||
      log.os_version.toLowerCase().includes(searchTerm.toLowerCase()) ||
      log.stack_trace.toLowerCase().includes(searchTerm.toLowerCase())
    );
  }, [errorLogs, searchTerm]);

  const filteredHandshakeLogs = useMemo(() => {
    if (!searchTerm) return handshakeLogs;
    return handshakeLogs.filter(log =>
      log.parcel_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
      log.status.toLowerCase().includes(searchTerm.toLowerCase())
    );
  }, [handshakeLogs, searchTerm]);

  const errorStats = useMemo(() => {
    const devices: Record<string, number> = {};
    const osVersions: Record<string, number> = {};

    errorLogs.forEach(log => {
      devices[log.device_model] = (devices[log.device_model] || 0) + 1;
      osVersions[log.os_version] = (osVersions[log.os_version] || 0) + 1;
    });

    return {
      deviceCounts: Object.entries(devices).sort((a, b) => b[1] - a[1]),
      osVersionCounts: Object.entries(osVersions).sort((a, b) => b[1] - a[1])
    };
  }, [errorLogs]);

  const exportLogs = () => {
    const data = tab === 'errors' ? filteredErrorLogs : filteredHandshakeLogs;
    const csvContent = [
      Object.keys(data[0] || {}).join(','),
      ...data.map(row => Object.values(row).join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${tab}-logs-${new Date().toISOString()}.csv`;
    a.click();
  };

  return (
    <div className="space-y-8 p-8">
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-4xl font-bold text-white mb-2">System Logs</h1>
          <p className="text-slate-400">View error logs, handshake events, and system health</p>
        </div>
        <div className="flex gap-2">
          <Button
            onClick={loadLogs}
            disabled={loading}
            variant="outline"
            className="bg-slate-700 border-slate-600 text-white hover:bg-slate-600"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </Button>
          <Button
            onClick={exportLogs}
            className="bg-blue-600 hover:bg-blue-700 text-white"
          >
            <Download className="w-4 h-4 mr-2" />
            Export CSV
          </Button>
        </div>
      </div>

      {error && (
        <div className="flex gap-2 p-4 bg-red-500/10 border border-red-500/20 rounded-lg">
          <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
          <p className="text-red-400 text-sm">{error}</p>
        </div>
      )}

      {/* Controls */}
      <div className="flex gap-4 items-end">
        <div>
          <label className="block text-sm font-medium text-slate-300 mb-2">Time Range</label>
          <select
            value={days}
            onChange={(e) => setDays(parseInt(e.target.value))}
            className="px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white focus:border-blue-500 focus:outline-none"
          >
            <option value={1}>Last 24 hours</option>
            <option value={7}>Last 7 days</option>
            <option value={30}>Last 30 days</option>
          </select>
        </div>

        <div className="flex-1">
          <label className="block text-sm font-medium text-slate-300 mb-2">Search</label>
          <div className="relative">
            <Search className="absolute left-3 top-2.5 w-4 h-4 text-slate-500" />
            <input
              type="text"
              placeholder="Search logs..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-3 py-2 bg-slate-700 border border-slate-600 rounded text-white placeholder-slate-500 focus:border-blue-500 focus:outline-none"
            />
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-2">
          <Button
            onClick={() => setTab('errors')}
            variant={tab === 'errors' ? 'default' : 'outline'}
            className={tab === 'errors' ? 'bg-blue-600 hover:bg-blue-700' : 'bg-slate-700 border-slate-600 text-white hover:bg-slate-600'}
          >
            Error Logs
          </Button>
          <Button
            onClick={() => setTab('handshake')}
            variant={tab === 'handshake' ? 'default' : 'outline'}
            className={tab === 'handshake' ? 'bg-blue-600 hover:bg-blue-700' : 'bg-slate-700 border-slate-600 text-white hover:bg-slate-600'}
          >
            Handshakes
          </Button>
        </div>
      </div>

      {tab === 'errors' ? (
        <>
          {/* Error Stats */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Card className="bg-slate-800 border-slate-700">
              <CardHeader>
                <CardTitle className="text-white text-sm">Top Devices</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  {errorStats.deviceCounts.slice(0, 5).map(([device, count]) => (
                    <div key={device} className="flex justify-between items-center">
                      <span className="text-slate-300">{device}</span>
                      <Badge className="bg-blue-500/20 text-blue-400 border-0">{count}</Badge>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>

            <Card className="bg-slate-800 border-slate-700">
              <CardHeader>
                <CardTitle className="text-white text-sm">Top OS Versions</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  {errorStats.osVersionCounts.slice(0, 5).map(([version, count]) => (
                    <div key={version} className="flex justify-between items-center">
                      <span className="text-slate-300">{version}</span>
                      <Badge className="bg-purple-500/20 text-purple-400 border-0">{count}</Badge>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Error Logs Table */}
          <Card className="bg-slate-800 border-slate-700">
            <CardHeader>
              <CardTitle className="text-white">Error Logs ({filteredErrorLogs.length})</CardTitle>
              <CardDescription className="text-slate-400">Client application errors</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-slate-700">
                      <th className="text-left py-3 px-4 font-medium text-slate-300">Device Model</th>
                      <th className="text-left py-3 px-4 font-medium text-slate-300">OS Version</th>
                      <th className="text-left py-3 px-4 font-medium text-slate-300">Stack Trace</th>
                      <th className="text-left py-3 px-4 font-medium text-slate-300">Occurred At</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredErrorLogs.map(log => (
                      <tr key={log.id} className="border-b border-slate-700 hover:bg-slate-700/50">
                        <td className="py-3 px-4 text-slate-300">{log.device_model}</td>
                        <td className="py-3 px-4 text-slate-300">{log.os_version}</td>
                        <td className="py-3 px-4 text-slate-400 text-xs font-mono max-w-xs truncate">{log.stack_trace}</td>
                        <td className="py-3 px-4 text-slate-400">
                          {new Date(log.occurred_at).toLocaleString()}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {filteredErrorLogs.length === 0 && (
                  <div className="text-center py-8 text-slate-400">No error logs found</div>
                )}
              </div>
            </CardContent>
          </Card>
        </>
      ) : (
        <Card className="bg-slate-800 border-slate-700">
          <CardHeader>
            <CardTitle className="text-white">Handshake Events ({filteredHandshakeLogs.length})</CardTitle>
            <CardDescription className="text-slate-400">Pickup and delivery verification events</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-700">
                    <th className="text-left py-3 px-4 font-medium text-slate-300">Parcel ID</th>
                    <th className="text-left py-3 px-4 font-medium text-slate-300">Step</th>
                    <th className="text-left py-3 px-4 font-medium text-slate-300">Status</th>
                    <th className="text-left py-3 px-4 font-medium text-slate-300">Location</th>
                    <th className="text-left py-3 px-4 font-medium text-slate-300">Accuracy</th>
                    <th className="text-left py-3 px-4 font-medium text-slate-300">Created At</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredHandshakeLogs.map(log => (
                    <tr key={log.id} className="border-b border-slate-700 hover:bg-slate-700/50">
                      <td className="py-3 px-4 font-mono text-slate-200">{log.parcel_id.slice(0, 8)}...</td>
                      <td className="py-3 px-4 text-slate-300">{log.step}</td>
                      <td className="py-3 px-4">
                        <Badge className={log.status === 'SUCCESS' ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'}>
                          {log.status}
                        </Badge>
                      </td>
                      <td className="py-3 px-4 text-slate-400 text-xs">{log.lat.toFixed(4)}, {log.lng.toFixed(4)}</td>
                      <td className="py-3 px-4 text-slate-400">{log.accuracy_m}m</td>
                      <td className="py-3 px-4 text-slate-400">
                        {new Date(log.created_at).toLocaleString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {filteredHandshakeLogs.length === 0 && (
                <div className="text-center py-8 text-slate-400">No handshake events found</div>
              )}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
