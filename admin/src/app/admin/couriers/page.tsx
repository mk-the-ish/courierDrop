"use client";

import { useEffect, useState } from "react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

const baseUrl = process.env.NEXT_PUBLIC_API_URL || "https://dropcity-backend.onrender.com";

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

  useEffect(() => {
    const run = async () => {
      try {
        setLoading(true);
        const token = localStorage.getItem("admin_token") || localStorage.getItem("adminToken");
        const res = await fetch(`${baseUrl}/admin/couriers?limit=200`, {
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json"
          }
        });
        if (!res.ok) {
          throw new Error("Failed to fetch couriers");
        }
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

  return (
    <div className="space-y-6">
      <PageHeader title="Couriers" description="Live courier status from users.is_active and users.current_route_id" />
      <Card>
        <CardHeader>
          <CardTitle>Courier Fleet</CardTitle>
        </CardHeader>
        <CardContent>
          {loading ? (
            <p>Loading...</p>
          ) : rows.length === 0 ? (
            <p className="text-sm text-gray-500">No courier rows found.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="py-2 text-left">Courier</th>
                    <th className="py-2 text-left">Contact</th>
                    <th className="py-2 text-left">Active</th>
                    <th className="py-2 text-left">Current Route</th>
                    <th className="py-2 text-left">Created</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row) => (
                    <tr key={row.id} className="border-b">
                      <td className="py-2">
                        <div className="font-medium">{row.display_name || "Unknown"}</div>
                        <div className="text-xs text-gray-500">{row.id}</div>
                      </td>
                      <td className="py-2">
                        <div>{row.email || "-"}</div>
                        <div className="text-xs text-gray-500">{row.phone_number || "-"}</div>
                      </td>
                      <td className="py-2">
                        <Badge className={row.is_active ? "bg-green-100 text-green-800" : "bg-gray-100 text-gray-700"}>
                          {row.is_active ? "Active" : "Inactive"}
                        </Badge>
                      </td>
                      <td className="py-2 font-mono text-xs">{row.current_route_id || "None"}</td>
                      <td className="py-2">{new Date(row.created_at).toLocaleString()}</td>
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
