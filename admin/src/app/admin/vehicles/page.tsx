"use client";

import { useEffect, useState } from 'react';
import { CheckCircle, XCircle, AlertCircle, Loader2 } from 'lucide-react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import StatCard from '@/components/StatCard';
import { PageHeader } from '@/components/page-header';

const baseUrl = process.env.NEXT_PUBLIC_API_URL || 'https://dropcity-backend.onrender.com';

type Vehicle = {
  id: string;
  courier_id: string;
  vehicle_type: string;
  make: string;
  model: string;
  year: number;
  color: string;
  license_plate: string;
  max_capacity_kg: number;
  is_active: boolean;
  verification_status: 'unverified' | 'verified' | 'rejected';
  created_at: string;
  users: {
    id: string;
    email: string;
    display_name: string;
    phone_number: string;
    role: string;
  };
};

export default function VehicleVerificationPage() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [stats, setStats] = useState({
    total: 0,
    unverified: 0,
    verified: 0,
    rejected: 0,
  });
  const [filter, setFilter] = useState('unverified');
  const [loading, setLoading] = useState(true);
  const [verifying, setVerifying] = useState<string | null>(null);
  const [offset, setOffset] = useState(0);

  useEffect(() => {
    fetchVehicles();
    fetchStats();
  }, [filter, offset]);

  const fetchVehicles = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem('admin_token');
      const response = await fetch(
        `${baseUrl}/admin/vehicles?status=${filter}&limit=20&offset=${offset}`,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        }
      );

      if (!response.ok) throw new Error('Failed to fetch vehicles');
      const data = await response.json();
      setVehicles(data.vehicles || []);
    } catch (error) {
      console.error('Error fetching vehicles:', error);
      setVehicles([]);
    } finally {
      setLoading(false);
    }
  };

  const fetchStats = async () => {
    try {
      const token = localStorage.getItem('admin_token');
      const statuses = ['unverified', 'verified', 'rejected'];
      const newStats = { total: 0, unverified: 0, verified: 0, rejected: 0 };

      for (const status of statuses) {
        const response = await fetch(
          `${baseUrl}/admin/vehicles?status=${status}&limit=1`,
          {
            headers: {
              'Authorization': `Bearer ${token}`,
              'Content-Type': 'application/json',
            },
          }
        );

        if (response.ok) {
          const data = await response.json();
          const count = data.total || 0;
          newStats[status as keyof typeof newStats] = count;
          newStats.total += count;
        }
      }

      setStats(newStats);
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  };

  const handleVerify = async (vehicleId: string, approved: boolean) => {
    try {
      setVerifying(vehicleId);
      const token = localStorage.getItem('admin_token');
      const response = await fetch(`${baseUrl}/admin/vehicles/${vehicleId}/verify`, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          verified: approved,
          notes: '',
        }),
      });

      if (!response.ok) throw new Error('Failed to verify vehicle');

      // Refresh vehicles list
      await fetchVehicles();
      await fetchStats();
    } catch (error) {
      console.error('Error verifying vehicle:', error);
      alert('Failed to verify vehicle');
    } finally {
      setVerifying(null);
    }
  };

  const getStatusBadgeColor = (status: string) => {
    switch (status) {
      case 'verified':
        return 'bg-green-100 text-green-800';
      case 'rejected':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-yellow-100 text-yellow-800';
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'verified':
        return <CheckCircle className="w-4 h-4 text-green-600" />;
      case 'rejected':
        return <XCircle className="w-4 h-4 text-red-600" />;
      default:
        return <AlertCircle className="w-4 h-4 text-yellow-600" />;
    }
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title="Vehicle Verification"
        description="Review and verify courier vehicles"
      />

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Total Vehicles"
          value={stats.total}
          color="teal"
        />
        <StatCard
          title="Pending"
          value={stats.unverified}
          icon={AlertCircle}
          color="amber"
        />
        <StatCard
          title="Verified"
          value={stats.verified}
          icon={CheckCircle}
          color="green"
        />
        <StatCard
          title="Rejected"
          value={stats.rejected}
          icon={XCircle}
          color="red"
        />
      </div>

      {/* Filter */}
      <div className="flex gap-2 flex-wrap">
        {['unverified', 'verified', 'rejected'].map((status) => (
          <button
            key={status}
            onClick={() => {
              setFilter(status);
              setOffset(0);
            }}
            className={`px-4 py-2 rounded-lg font-medium transition-colors ${
              filter === status
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            {status.charAt(0).toUpperCase() + status.slice(1)}
          </button>
        ))}
      </div>

      {/* Vehicles Table */}
      <Card>
        <CardHeader>
          <CardTitle>
            Vehicles ({filter.charAt(0).toUpperCase() + filter.slice(1)})
          </CardTitle>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="flex justify-center py-8">
              <Loader2 className="w-6 h-6 animate-spin text-blue-600" />
            </div>
          ) : vehicles.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              No {filter} vehicles found
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="text-left py-3 px-4 font-medium">Vehicle</th>
                    <th className="text-left py-3 px-4 font-medium">Courier</th>
                    <th className="text-left py-3 px-4 font-medium">License Plate</th>
                    <th className="text-left py-3 px-4 font-medium">Capacity</th>
                    <th className="text-left py-3 px-4 font-medium">Status</th>
                    <th className="text-left py-3 px-4 font-medium">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {vehicles.map((vehicle) => (
                    <tr key={vehicle.id} className="border-b hover:bg-gray-50">
                      <td className="py-3 px-4">
                        <div>
                          <div className="font-medium">
                            {vehicle.year} {vehicle.make} {vehicle.model}
                          </div>
                          <div className="text-xs text-gray-500">{vehicle.vehicle_type}</div>
                        </div>
                      </td>
                      <td className="py-3 px-4">
                        <div>
                          <div className="font-medium">{vehicle.users?.display_name}</div>
                          <div className="text-xs text-gray-500">{vehicle.users?.email}</div>
                        </div>
                      </td>
                      <td className="py-3 px-4 font-mono">{vehicle.license_plate}</td>
                      <td className="py-3 px-4">{vehicle.max_capacity_kg} kg</td>
                      <td className="py-3 px-4">
                        <Badge className={getStatusBadgeColor(vehicle.verification_status)}>
                          <span className="inline-flex items-center gap-1">
                            {getStatusIcon(vehicle.verification_status)}
                            {vehicle.verification_status.charAt(0).toUpperCase() +
                              vehicle.verification_status.slice(1)}
                          </span>
                        </Badge>
                      </td>
                      <td className="py-3 px-4">
                        {vehicle.verification_status === 'unverified' && (
                          <div className="flex gap-2">
                            <button
                              onClick={() => handleVerify(vehicle.id, true)}
                              disabled={verifying === vehicle.id}
                              className="px-3 py-1 bg-green-600 text-white text-xs rounded hover:bg-green-700 disabled:opacity-50"
                            >
                              {verifying === vehicle.id ? (
                                <Loader2 className="w-3 h-3 animate-spin" />
                              ) : (
                                'Approve'
                              )}
                            </button>
                            <button
                              onClick={() => handleVerify(vehicle.id, false)}
                              disabled={verifying === vehicle.id}
                              className="px-3 py-1 bg-red-600 text-white text-xs rounded hover:bg-red-700 disabled:opacity-50"
                            >
                              {verifying === vehicle.id ? (
                                <Loader2 className="w-3 h-3 animate-spin" />
                              ) : (
                                'Reject'
                              )}
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              {/* Pagination */}
              <div className="flex justify-between items-center mt-4 pt-4 border-t">
                <button
                  onClick={() => setOffset(Math.max(0, offset - 20))}
                  disabled={offset === 0}
                  className="px-4 py-2 bg-gray-100 rounded disabled:opacity-50"
                >
                  Previous
                </button>
                <span className="text-sm text-gray-600">
                  Showing {offset + 1}-{Math.min(offset + 20, (stats as any)[filter] || 0)} of{' '}
                  {(stats as any)[filter] || 0}
                </span>
                <button
                  onClick={() => setOffset(offset + 20)}
                  disabled={offset + 20 >= ((stats as any)[filter] || 0)}
                  className="px-4 py-2 bg-gray-100 rounded disabled:opacity-50"
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
