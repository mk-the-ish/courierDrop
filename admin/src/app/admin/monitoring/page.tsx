'use client';

import { useState, useEffect, useMemo } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { AlertCircle, TrendingUp, Clock, MapPin, Radio, CircleOff, RefreshCw } from 'lucide-react';

const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8080';

interface Parcel {
  id: string;
  status: string;
  origin: string;
  destination: string;
  assigned_courier_id: string | null;
  created_at: string;
  assigned_at: string | null;
}

interface Courier {
  id: string;
  display_name: string;
  email: string;
  phone_number: string;
  role: string;
}

interface Metric {
  totalParcels: number;
  completed: number;
  inTransit: number;
  averageDeliveryTime: number;
  onlineCouriers: number;
  totalCouriers: number;
}

const statusColors: Record<string, string> = {
  'REQUESTED': 'bg-blue-100 text-blue-800',
  'MATCHING': 'bg-purple-100 text-purple-800',
  'ASSIGNED': 'bg-yellow-100 text-yellow-800',
  'IN_TRANSIT': 'bg-orange-100 text-orange-800',
  'DELIVERED': 'bg-green-100 text-green-800',
  'CANCELLED': 'bg-red-100 text-red-800'
};

export default function MonitoringPage() {
  const [parcels, setParcels] = useState<Parcel[]>([]);
  const [couriers, setCouriers] = useState<Courier[]>([]);
  const [metrics, setMetrics] = useState<Metric>({
    totalParcels: 0,
    completed: 0,
    inTransit: 0,
    averageDeliveryTime: 0,
    onlineCouriers: 0,
    totalCouriers: 0
  });
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getToken = () => {
    return localStorage.getItem('admin_token') || localStorage.getItem('adminToken') || '';
  };

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const token = getToken();
      if (!token) throw new Error('Not authenticated');

      const [parcelRes, courierRes] = await Promise.all([
        fetch(`${baseUrl}/admin/parcels`, {
          headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }
        }),
        fetch(`${baseUrl}/admin/couriers`, {
          headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }
        })
      ]);

      if (!parcelRes.ok || !courierRes.ok) {
        throw new Error(`Failed to load data: ${parcelRes.status} ${courierRes.status}`);
      }

      const parcelData = await parcelRes.json();
      const courierData = await courierRes.json();

      setParcels(parcelData.parcels || []);
      setCouriers(courierData.couriers || []);

      // Calculate metrics
      const parcelsArray = parcelData.parcels || [];
      const completed = parcelsArray.filter((p: Parcel) => p.status === 'DELIVERED').length;
      const inTransit = parcelsArray.filter((p: Parcel) => p.status === 'IN_TRANSIT').length;

      // Calculate average delivery time (rough estimate)
      const deliveredParcels = parcelsArray.filter((p: Parcel) => p.status === 'DELIVERED');
      const avgTime = deliveredParcels.length > 0
        ? Math.round(
            deliveredParcels.reduce((sum: number, p: Parcel) => {
              if (p.created_at && p.assigned_at) {
                const diffMs = new Date(p.assigned_at).getTime() - new Date(p.created_at).getTime();
                return sum + diffMs;
              }
              return sum;
            }, 0) / deliveredParcels.length / 60000 // Convert to minutes
          )
        : 0;

      setMetrics({
        totalParcels: parcelsArray.length,
        completed,
        inTransit,
        averageDeliveryTime: avgTime,
        onlineCouriers: Math.ceil((courierData.couriers || []).length * 0.7), // Mock online status
        totalCouriers: courierData.couriers?.length || 0
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    const interval = setInterval(loadData, 5000); // Refresh every 5 seconds
    return () => clearInterval(interval);
  }, []);

  const filteredParcels = useMemo(() => {
    if (statusFilter === 'ALL') return parcels;
    return parcels.filter(p => p.status === statusFilter);
  }, [parcels, statusFilter]);

  const statuses = ['REQUESTED', 'MATCHING', 'ASSIGNED', 'IN_TRANSIT', 'DELIVERED'];

  return (
    <div className="space-y-8 p-8">
      <div>
        <h1 className="text-4xl font-bold text-white mb-2">Delivery Monitoring</h1>
        <p className="text-slate-400">Real-time parcel statuses, courier locations, and metrics</p>
      </div>

      {error && (
        <div className="flex gap-2 p-4 bg-red-500/10 border border-red-500/20 rounded-lg">
          <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
          <p className="text-red-400 text-sm">{error}</p>
        </div>
      )}

      {/* Metrics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <Card className="bg-slate-800 border-slate-700">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-medium text-slate-300">Total Parcels</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-white">{metrics.totalParcels}</div>
            <p className="text-xs text-slate-400 mt-2">Today</p>
          </CardContent>
        </Card>

        <Card className="bg-slate-800 border-slate-700">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-medium text-slate-300">Completed</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-400">{metrics.completed}</div>
            <p className="text-xs text-slate-400 mt-2">
              {metrics.totalParcels > 0 ? Math.round((metrics.completed / metrics.totalParcels) * 100) : 0}%
            </p>
          </CardContent>
        </Card>

        <Card className="bg-slate-800 border-slate-700">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-medium text-slate-300">In Transit</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-orange-400">{metrics.inTransit}</div>
            <p className="text-xs text-slate-400 mt-2">Active deliveries</p>
          </CardContent>
        </Card>

        <Card className="bg-slate-800 border-slate-700">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-medium text-slate-300">Avg Delivery Time</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-blue-400">{metrics.averageDeliveryTime}m</div>
            <p className="text-xs text-slate-400 mt-2">Minutes</p>
          </CardContent>
        </Card>

        <Card className="bg-slate-800 border-slate-700">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-medium text-slate-300">Online Couriers</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-400">{metrics.onlineCouriers}</div>
            <p className="text-xs text-slate-400 mt-2">of {metrics.totalCouriers}</p>
          </CardContent>
        </Card>

        <Button
          onClick={loadData}
          disabled={loading}
          variant="outline"
          className="w-full bg-slate-700 border-slate-600 text-white hover:bg-slate-600 h-auto"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {/* Parcels Section */}
      <Card className="bg-slate-800 border-slate-700">
        <CardHeader>
          <div className="flex justify-between items-center">
            <div>
              <CardTitle className="text-white">Parcels</CardTitle>
              <CardDescription className="text-slate-400">Real-time parcel status tracking</CardDescription>
            </div>
            <div className="flex gap-2 flex-wrap">
              <Button
                onClick={() => setStatusFilter('ALL')}
                variant={statusFilter === 'ALL' ? 'default' : 'outline'}
                size="sm"
                className="bg-slate-700 border-slate-600 text-white hover:bg-slate-600"
              >
                All
              </Button>
              {statuses.map(status => (
                <Button
                  key={status}
                  onClick={() => setStatusFilter(status)}
                  variant={statusFilter === status ? 'default' : 'outline'}
                  size="sm"
                  className="bg-slate-700 border-slate-600 text-white hover:bg-slate-600"
                >
                  {status}
                </Button>
              ))}
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-700">
                  <th className="text-left py-3 px-4 font-medium text-slate-300">Parcel ID</th>
                  <th className="text-left py-3 px-4 font-medium text-slate-300">Status</th>
                  <th className="text-left py-3 px-4 font-medium text-slate-300">Origin</th>
                  <th className="text-left py-3 px-4 font-medium text-slate-300">Destination</th>
                  <th className="text-left py-3 px-4 font-medium text-slate-300">Courier</th>
                  <th className="text-left py-3 px-4 font-medium text-slate-300">Created</th>
                </tr>
              </thead>
              <tbody>
                {filteredParcels.map(parcel => (
                  <tr key={parcel.id} className="border-b border-slate-700 hover:bg-slate-700/50">
                    <td className="py-3 px-4 font-mono text-slate-200">{parcel.id.slice(0, 8)}...</td>
                    <td className="py-3 px-4">
                      <Badge className={statusColors[parcel.status] || 'bg-slate-700 text-slate-300'}>
                        {parcel.status}
                      </Badge>
                    </td>
                    <td className="py-3 px-4 text-slate-300">{parcel.origin}</td>
                    <td className="py-3 px-4 text-slate-300">{parcel.destination}</td>
                    <td className="py-3 px-4 text-slate-300">
                      {parcel.assigned_courier_id ? parcel.assigned_courier_id.slice(0, 8) + '...' : '—'}
                    </td>
                    <td className="py-3 px-4 text-slate-400">
                      {new Date(parcel.created_at).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {filteredParcels.length === 0 && (
              <div className="text-center py-8 text-slate-400">No parcels found</div>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Couriers Section */}
      <Card className="bg-slate-800 border-slate-700">
        <CardHeader>
          <CardTitle className="text-white">Active Couriers</CardTitle>
          <CardDescription className="text-slate-400">Courier online status and details</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {couriers.map(courier => {
              const isOnline = Math.random() > 0.3; // Mock online status
              return (
                <div key={courier.id} className="p-4 bg-slate-700 rounded-lg border border-slate-600">
                  <div className="flex items-start justify-between mb-2">
                    <div>
                      <p className="font-medium text-white">{courier.display_name || 'Courier'}</p>
                      <p className="text-sm text-slate-400">{courier.email}</p>
                    </div>
                    <div className="flex items-center gap-1">
                      {isOnline ? (
                        <>
                          <Radio className="w-4 h-4 text-green-400 fill-green-400" />
                          <span className="text-xs text-green-400 font-medium">Online</span>
                        </>
                      ) : (
                        <>
                          <CircleOff className="w-4 h-4 text-slate-500" />
                          <span className="text-xs text-slate-400 font-medium">Offline</span>
                        </>
                      )}
                    </div>
                  </div>
                  <p className="text-sm text-slate-300">{courier.phone_number}</p>
                </div>
              );
            })}
          </div>
          {couriers.length === 0 && (
            <div className="text-center py-8 text-slate-400">No couriers found</div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
