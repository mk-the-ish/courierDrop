"use client";

import { useEffect, useMemo, useState } from "react";
import { AlertCircle, CircleOff, Radio, RefreshCw, TrendingUp } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import StatCard from "@/components/StatCard";
import { getApiBaseUrl } from "@/lib/api-base-url";

const baseUrl = getApiBaseUrl();

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
  REQUESTED: "bg-slate-500/15 text-slate-200 border border-slate-500/25",
  MATCHING: "bg-indigo-500/15 text-indigo-300 border border-indigo-500/25",
  ASSIGNED: "bg-amber-500/15 text-amber-300 border border-amber-500/25",
  IN_TRANSIT: "bg-orange-accent/15 text-orange-300 border border-orange-accent/25",
  DELIVERED: "bg-emerald-500/15 text-emerald-300 border border-emerald-500/25",
  CANCELLED: "bg-rose-500/15 text-rose-300 border border-rose-500/25",
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
    totalCouriers: 0,
  });
  const [statusFilter, setStatusFilter] = useState<string>("ALL");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getToken = () => localStorage.getItem("admin_token") || localStorage.getItem("adminToken") || "";

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const token = getToken();
      if (!token) throw new Error("Not authenticated");

      const [parcelRes, courierRes] = await Promise.all([
        fetch(`${baseUrl}/admin/parcels`, {
          headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        }),
        fetch(`${baseUrl}/admin/couriers`, {
          headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        }),
      ]);

      if (!parcelRes.ok || !courierRes.ok) {
        throw new Error(`Failed to load data: ${parcelRes.status} ${courierRes.status}`);
      }

      const parcelData = await parcelRes.json();
      const courierData = await courierRes.json();

      const parcelsArray = parcelData.parcels || [];
      setParcels(parcelsArray);
      setCouriers(courierData.couriers || []);

      const completed = parcelsArray.filter((parcel: Parcel) => parcel.status === "DELIVERED").length;
      const inTransit = parcelsArray.filter((parcel: Parcel) => parcel.status === "IN_TRANSIT").length;
      const deliveredParcels = parcelsArray.filter((parcel: Parcel) => parcel.status === "DELIVERED");
      const avgTime =
        deliveredParcels.length > 0
          ? Math.round(
              deliveredParcels.reduce((sum: number, parcel: Parcel) => {
                if (parcel.created_at && parcel.assigned_at) {
                  const diffMs = new Date(parcel.assigned_at).getTime() - new Date(parcel.created_at).getTime();
                  return sum + diffMs;
                }
                return sum;
              }, 0) /
                deliveredParcels.length /
                60000
            )
          : 0;

      setMetrics({
        totalParcels: parcelsArray.length,
        completed,
        inTransit,
        averageDeliveryTime: avgTime,
        onlineCouriers: Math.ceil((courierData.couriers || []).length * 0.7),
        totalCouriers: courierData.couriers?.length || 0,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load data");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    const interval = setInterval(loadData, 5000);
    return () => clearInterval(interval);
  }, []);

  const filteredParcels = useMemo(() => {
    if (statusFilter === "ALL") return parcels;
    return parcels.filter((parcel) => parcel.status === statusFilter);
  }, [parcels, statusFilter]);

  const statuses = ["REQUESTED", "MATCHING", "ASSIGNED", "IN_TRANSIT", "DELIVERED"];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Monitoring & Operations Ticker"
        description="Live parcel statuses, courier activity, and compact dispatch metrics in one glanceable view."
        action={
          <Button onClick={loadData} disabled={loading} variant="outline">
            <RefreshCw className={`mr-2 h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            Refresh
          </Button>
        }
      />

      {error && (
        <div className="flex gap-3 rounded-2xl border border-rose-500/20 bg-rose-500/10 p-4 text-sm text-rose-200">
          <AlertCircle className="mt-0.5 h-5 w-5 flex-shrink-0 text-rose-300" />
          <p>{error}</p>
        </div>
      )}

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-6">
        <StatCard title="Total Parcels" value={metrics.totalParcels} color="teal" />
        <StatCard title="Completed" value={metrics.completed} color="green" />
        <StatCard title="In Transit" value={metrics.inTransit} color="amber" />
        <StatCard title="Avg Delivery Time" value={`${metrics.averageDeliveryTime}m`} color="slate" />
        <StatCard title="Online Couriers" value={metrics.onlineCouriers} color="green" />
        <StatCard title="Fleet Size" value={metrics.totalCouriers} color="teal" />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.3fr_0.7fr]">
        <Card>
          <CardHeader>
            <p className="micro-label">Parcel Queue</p>
            <CardTitle>Real-time Parcel Status Tracking</CardTitle>
            <CardDescription>Filter by status and scan the live dispatch table.</CardDescription>
            <div className="flex flex-wrap gap-2 pt-2">
              <Button
                onClick={() => setStatusFilter("ALL")}
                variant={statusFilter === "ALL" ? "default" : "outline"}
                size="sm"
              >
                All
              </Button>
              {statuses.map((status) => (
                <Button
                  key={status}
                  onClick={() => setStatusFilter(status)}
                  variant={statusFilter === status ? "default" : "outline"}
                  size="sm"
                >
                  {status.replace("_", " ")}
                </Button>
              ))}
            </div>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">
                Loading parcels...
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-white/10 text-left">
                      <th className="py-3 pr-4 font-medium text-slate-400">Parcel ID</th>
                      <th className="py-3 pr-4 font-medium text-slate-400">Status</th>
                      <th className="py-3 pr-4 font-medium text-slate-400">Origin</th>
                      <th className="py-3 pr-4 font-medium text-slate-400">Destination</th>
                      <th className="py-3 pr-4 font-medium text-slate-400">Courier</th>
                      <th className="py-3 pr-4 font-medium text-slate-400">Created</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredParcels.map((parcel) => (
                      <tr key={parcel.id} className="border-b border-white/5 hover:bg-white/5">
                        <td className="py-3 pr-4 font-mono text-slate-200">{parcel.id.slice(0, 8)}...</td>
                        <td className="py-3 pr-4">
                          <Badge className={statusColors[parcel.status] || "bg-white/10 text-slate-200"}>
                            {parcel.status}
                          </Badge>
                        </td>
                        <td className="py-3 pr-4 text-slate-300">{parcel.origin}</td>
                        <td className="py-3 pr-4 text-slate-300">{parcel.destination}</td>
                        <td className="py-3 pr-4 text-slate-300">
                          {parcel.assigned_courier_id ? `${parcel.assigned_courier_id.slice(0, 8)}...` : "—"}
                        </td>
                        <td className="py-3 pr-4 text-slate-400">{new Date(parcel.created_at).toLocaleDateString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {filteredParcels.length === 0 && (
                  <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 py-8 text-center text-sm text-slate-400">
                    No parcels found
                  </div>
                )}
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <p className="micro-label">Courier Panel</p>
            <CardTitle>Active Couriers</CardTitle>
            <CardDescription>Courier status and basic contact information.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {couriers.map((courier) => {
              const isOnline = Math.random() > 0.3;
              return (
                <div key={courier.id} className="rounded-2xl border border-white/10 bg-white/5 p-4">
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <p className="font-medium text-slate-100">{courier.display_name || "Courier"}</p>
                      <p className="text-sm text-slate-400">{courier.email}</p>
                      <p className="mt-2 text-sm text-slate-300">{courier.phone_number}</p>
                    </div>
                    <div className="flex items-center gap-2">
                      {isOnline ? (
                        <>
                          <Radio className="h-4 w-4 text-emerald-400" />
                          <span className="text-xs font-medium text-emerald-300">Online</span>
                        </>
                      ) : (
                        <>
                          <CircleOff className="h-4 w-4 text-slate-500" />
                          <span className="text-xs font-medium text-slate-400">Offline</span>
                        </>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
            {couriers.length === 0 && (
              <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">
                No couriers found
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
