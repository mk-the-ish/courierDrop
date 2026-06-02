"use client";

import { useEffect, useMemo, useState } from "react";
import { AlertCircle, CheckCircle, Loader2, Search, XCircle } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import StatCard from "@/components/StatCard";
import { getApiBaseUrl } from "@/lib/api-base-url";

const baseUrl = getApiBaseUrl();

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
  verification_status: "unverified" | "verified" | "rejected";
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
  const [filter, setFilter] = useState("unverified");
  const [loading, setLoading] = useState(true);
  const [verifying, setVerifying] = useState<string | null>(null);
  const [offset, setOffset] = useState(0);
  const [query, setQuery] = useState("");

  const token = typeof window !== "undefined" ? (localStorage.getItem("admin_token") || localStorage.getItem("adminToken")) : "";

  const fetchVehicles = async () => {
    try {
      setLoading(true);
      const endpoint =
        filter === "unverified"
          ? `${baseUrl}/admin/vehicles/pending?limit=20&offset=${offset}`
          : `${baseUrl}/admin/vehicles?status=${filter}&limit=20&offset=${offset}`;
      const response = await fetch(endpoint, {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });

      if (!response.ok) throw new Error("Failed to fetch vehicles");
      const data = await response.json();
      setVehicles(data.vehicles || []);
    } catch (error) {
      console.error("Error fetching vehicles:", error);
      setVehicles([]);
    } finally {
      setLoading(false);
    }
  };

  const fetchStats = async () => {
    try {
      const statuses = ["unverified", "verified", "rejected"];
      const newStats = { total: 0, unverified: 0, verified: 0, rejected: 0 };

      for (const status of statuses) {
        const response = await fetch(`${baseUrl}/admin/vehicles?status=${status}&limit=1`, {
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
        });

        if (response.ok) {
          const data = await response.json();
          const count = data.total || 0;
          newStats[status as keyof typeof newStats] = count;
          newStats.total += count;
        }
      }

      setStats(newStats);
    } catch (error) {
      console.error("Error fetching stats:", error);
    }
  };

  useEffect(() => {
    fetchVehicles();
    fetchStats();
  }, [filter, offset]);

  const handleVerify = async (vehicleId: string, approved: boolean) => {
    try {
      setVerifying(vehicleId);
      const response = await fetch(`${baseUrl}/admin/vehicles/${vehicleId}/verify`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          approved,
          notes: "",
        }),
      });

      if (!response.ok) throw new Error("Failed to verify vehicle");
      await fetchVehicles();
      await fetchStats();
    } catch (error) {
      console.error("Error verifying vehicle:", error);
      alert("Failed to verify vehicle");
    } finally {
      setVerifying(null);
    }
  };

  const filteredVehicles = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return vehicles;
    return vehicles.filter((vehicle) =>
      [vehicle.make, vehicle.model, vehicle.license_plate, vehicle.users?.display_name, vehicle.users?.email]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(term))
    );
  }, [query, vehicles]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Vehicle Verification"
        description="Review courier vehicles with a compact queue, clear states, and fast approve/reject actions."
      />

      <div className="grid gap-4 md:grid-cols-4">
        <StatCard title="Total Vehicles" value={stats.total} color="teal" />
        <StatCard title="Pending" value={stats.unverified} color="amber" />
        <StatCard title="Verified" value={stats.verified} color="green" />
        <StatCard title="Rejected" value={stats.rejected} color="red" />
      </div>

      <Card>
        <CardHeader className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="micro-label">Verification Queue</p>
            <CardTitle>Vehicles ({filter.charAt(0).toUpperCase() + filter.slice(1)})</CardTitle>
            <CardDescription>Search, inspect, and verify registration records.</CardDescription>
          </div>
          <div className="relative w-full md:max-w-sm">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" size={16} />
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search vehicle, courier, plate..."
              className="pl-10"
            />
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex flex-wrap gap-2">
            {["unverified", "verified", "rejected"].map((status) => (
              <Button
                key={status}
                onClick={() => {
                  setFilter(status);
                  setOffset(0);
                }}
                variant={filter === status ? "default" : "outline"}
                size="sm"
              >
                {status.charAt(0).toUpperCase() + status.slice(1)}
              </Button>
            ))}
          </div>

          {loading ? (
            <div className="flex justify-center rounded-2xl border border-dashed border-white/10 bg-white/5 py-10">
              <Loader2 className="h-6 w-6 animate-spin text-orange-accent" />
            </div>
          ) : filteredVehicles.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-center text-sm text-slate-400">
              No {filter} vehicles found
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-white/10 text-left">
                    <th className="py-3 pr-4 font-medium text-slate-400">Vehicle</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Courier</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Plate</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Capacity</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Status</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredVehicles.map((vehicle) => (
                    <tr key={vehicle.id} className="border-b border-white/5 hover:bg-white/5">
                      <td className="py-4 pr-4">
                        <div className="font-medium text-slate-100">
                          {vehicle.year} {vehicle.make} {vehicle.model}
                        </div>
                        <div className="text-xs text-slate-500">{vehicle.vehicle_type}</div>
                      </td>
                      <td className="py-4 pr-4">
                        <div className="font-medium text-slate-200">{vehicle.users?.display_name}</div>
                        <div className="text-xs text-slate-500">{vehicle.users?.email}</div>
                      </td>
                      <td className="py-4 pr-4 font-mono text-slate-200">{vehicle.license_plate}</td>
                      <td className="py-4 pr-4 text-slate-300">{vehicle.max_capacity_kg} kg</td>
                      <td className="py-4 pr-4">
                        <Badge
                          variant={
                            vehicle.verification_status === "verified"
                              ? "success"
                              : vehicle.verification_status === "rejected"
                                ? "error"
                                : "warning"
                          }
                        >
                          <span className="inline-flex items-center gap-1">
                            {vehicle.verification_status === "verified" ? (
                              <CheckCircle className="h-3.5 w-3.5" />
                            ) : vehicle.verification_status === "rejected" ? (
                              <XCircle className="h-3.5 w-3.5" />
                            ) : (
                              <AlertCircle className="h-3.5 w-3.5" />
                            )}
                            {vehicle.verification_status.charAt(0).toUpperCase() + vehicle.verification_status.slice(1)}
                          </span>
                        </Badge>
                      </td>
                      <td className="py-4 pr-4">
                        {vehicle.verification_status === "unverified" ? (
                          <div className="flex gap-2">
                            <Button
                              size="sm"
                              onClick={() => handleVerify(vehicle.id, true)}
                              disabled={verifying === vehicle.id}
                            >
                              {verifying === vehicle.id ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : "Approve"}
                            </Button>
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleVerify(vehicle.id, false)}
                              disabled={verifying === vehicle.id}
                            >
                              Reject
                            </Button>
                          </div>
                        ) : (
                          <span className="text-xs text-slate-500">No action</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
