"use client";

import { useEffect, useMemo, useState } from "react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const baseUrl = process.env.NEXT_PUBLIC_API_URL || "https://dropcity-backend.onrender.com";

type ErrorLogRow = {
  id: string;
  level: string;
  message: string;
  device: string;
  timestamp: string;
};

type HandshakeLogRow = {
  id: string;
  parcel_id: string;
  step: string;
  status: string;
  spatial_gate_distance_m: number | null;
  hash_verification_status: string;
  created_at: string;
};

export default function LogsPage() {
  const [tab, setTab] = useState<"errors" | "handshake">("errors");
  const [errorLogs, setErrorLogs] = useState<ErrorLogRow[]>([]);
  const [handshakeLogs, setHandshakeLogs] = useState<HandshakeLogRow[]>([]);

  useEffect(() => {
    const run = async () => {
      const token = localStorage.getItem("admin_token") || localStorage.getItem("adminToken");
      const res = await fetch(`${baseUrl}/admin/logs?limit=200&days=14`, {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json"
        }
      });
      if (!res.ok) {
        setErrorLogs([]);
        setHandshakeLogs([]);
        return;
      }
      const data = await res.json();
      setErrorLogs(data.error_logs || []);
      setHandshakeLogs(data.handshake_events || []);
    };
    run();
  }, []);

  const tabTitle = useMemo(() => {
    return tab === "errors" ? "Error Logs" : "Handshake Events";
  }, [tab]);

  return (
    <div className="space-y-6">
      <PageHeader title="Logs" description="Dual view for runtime errors and handshake telemetry" />
      <div className="flex gap-2">
        <button className={`px-4 py-2 rounded ${tab === "errors" ? "bg-blue-600 text-white" : "bg-gray-100"}`} onClick={() => setTab("errors")}>error_logs</button>
        <button className={`px-4 py-2 rounded ${tab === "handshake" ? "bg-blue-600 text-white" : "bg-gray-100"}`} onClick={() => setTab("handshake")}>handshake_events</button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>{tabTitle}</CardTitle>
        </CardHeader>
        <CardContent>
          {tab === "errors" ? (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="py-2 text-left">Level</th>
                    <th className="py-2 text-left">Message</th>
                    <th className="py-2 text-left">Device</th>
                    <th className="py-2 text-left">Timestamp</th>
                  </tr>
                </thead>
                <tbody>
                  {errorLogs.map((row) => (
                    <tr key={row.id} className="border-b">
                      <td className="py-2">{row.level}</td>
                      <td className="py-2">{row.message}</td>
                      <td className="py-2">{row.device}</td>
                      <td className="py-2">{new Date(row.timestamp).toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="py-2 text-left">Parcel</th>
                    <th className="py-2 text-left">Step</th>
                    <th className="py-2 text-left">Status</th>
                    <th className="py-2 text-left">Spatial Gate Distance</th>
                    <th className="py-2 text-left">Hash Verification</th>
                    <th className="py-2 text-left">Timestamp</th>
                  </tr>
                </thead>
                <tbody>
                  {handshakeLogs.map((row) => (
                    <tr key={row.id} className="border-b">
                      <td className="py-2 font-mono text-xs">{row.parcel_id}</td>
                      <td className="py-2">{row.step}</td>
                      <td className="py-2">{row.status}</td>
                      <td className="py-2">{row.spatial_gate_distance_m == null ? "-" : `${row.spatial_gate_distance_m} m`}</td>
                      <td className="py-2">{row.hash_verification_status}</td>
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
