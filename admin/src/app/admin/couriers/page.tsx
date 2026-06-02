"use client";

import { useEffect, useMemo, useState } from "react";
import { Users, CircleCheckBig, CircleOff, Search } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import StatCard from "@/components/StatCard";
import { getApiBaseUrl } from "@/lib/api-base-url";

const baseUrl = getApiBaseUrl();

type CourierRow = {
  id: string;
  email: string;
  display_name: string;
  phone_number: string;
  role: string;
  is_active: boolean;
  current_route_id: string | null;
  created_at: string;
};

export default function CouriersPage() {
  const [rows, setRows] = useState<CourierRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");

  useEffect(() => {
    const run = async () => {
      try {
        setLoading(true);
        const token = localStorage.getItem("admin_token") || localStorage.getItem("adminToken");
        const res = await fetch(`${baseUrl}/admin/couriers?limit=200`, {
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
        });
        if (!res.ok) throw new Error("Failed to fetch couriers");
        const data = await res.json();
        setRows(data.couriers || []);
      } catch {
        setRows([]);
      } finally {
        setLoading(false);
      }
    };
    run();
  }, []);

  const filteredRows = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return rows;
    return rows.filter((row) =>
      [row.display_name, row.email, row.phone_number, row.current_route_id]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(term))
    );
  }, [query, rows]);

  const activeCount = rows.filter((row) => row.is_active).length;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Couriers & Vehicles"
        description="Live courier records, routing state, and the current vehicle assignment footprint."
      />

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard title="Total Couriers" value={rows.length} icon={Users} color="teal" />
        <StatCard title="Active Couriers" value={activeCount} icon={CircleCheckBig} color="green" />
        <StatCard title="Inactive Couriers" value={rows.length - activeCount} icon={CircleOff} color="red" />
      </div>

      <Card>
        <CardHeader className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="micro-label">Fleet Directory</p>
            <CardTitle>Courier Fleet</CardTitle>
          </div>
          <div className="relative w-full md:max-w-sm">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" size={16} />
            <Input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search couriers, routes, phone numbers..."
              className="pl-10"
            />
          </div>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">
              Loading courier records...
            </div>
          ) : filteredRows.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">
              No courier rows found.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-white/10 text-left">
                    <th className="py-3 pr-4 font-medium text-slate-400">Courier</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Contact</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Status</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Route</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Created</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredRows.map((row) => (
                    <tr key={row.id} className="border-b border-white/5 hover:bg-white/5">
                      <td className="py-4 pr-4">
                        <div className="font-medium text-slate-100">{row.display_name || "Unknown"}</div>
                        <div className="text-xs text-slate-500">{row.id}</div>
                      </td>
                      <td className="py-4 pr-4">
                        <div className="text-slate-200">{row.email || "-"}</div>
                        <div className="text-xs text-slate-500">{row.phone_number || "-"}</div>
                      </td>
                      <td className="py-4 pr-4">
                        <Badge variant={row.is_active ? "success" : "secondary"}>
                          {row.is_active ? "Active" : "Inactive"}
                        </Badge>
                      </td>
                      <td className="py-4 pr-4 font-mono text-xs text-slate-300">{row.current_route_id || "None"}</td>
                      <td className="py-4 pr-4 text-slate-400">{new Date(row.created_at).toLocaleString()}</td>
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
