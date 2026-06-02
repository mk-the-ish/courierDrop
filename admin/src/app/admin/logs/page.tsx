"use client";

import { useEffect, useMemo, useState } from "react";
import { Search, ScrollText, Activity, HardDrive, Smartphone } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import StatCard from "@/components/StatCard";
import { getApiBaseUrl } from "@/lib/api-base-url";

const baseUrl = getApiBaseUrl();

type ErrorLog = {
  id: string;
  message: string;
  stack_trace: string;
  device_model: string;
  os_version: string;
  created_at: string;
};

type HandshakeLog = {
  id: string;
  parcel_id: string;
  step: string;
  status: string;
  lat: number;
  lng: number;
  accuracy_m: number;
  created_at: string;
};

export default function LogsPage() {
  const [errorLogs, setErrorLogs] = useState<ErrorLog[]>([]);
  const [handshakeLogs, setHandshakeLogs] = useState<HandshakeLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<"errors" | "handshake">("errors");
  const [query, setQuery] = useState("");

  useEffect(() => {
    const run = async () => {
      const token = localStorage.getItem("admin_token") || localStorage.getItem("adminToken");
      const [errorRes, handshakeRes] = await Promise.all([
        fetch(`${baseUrl}/admin/logs/errors?limit=200`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        fetch(`${baseUrl}/admin/logs/handshake?limit=200`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
      ]);

      if (errorRes.ok) {
        const data = await errorRes.json();
        setErrorLogs(data.logs || []);
      }
      if (handshakeRes.ok) {
        const data = await handshakeRes.json();
        setHandshakeLogs(data.logs || []);
      }
      setLoading(false);
    };
    run();
  }, []);

  const filteredErrorLogs = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return errorLogs;
    return errorLogs.filter((log) =>
      [log.message, log.stack_trace, log.device_model, log.os_version]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(term))
    );
  }, [errorLogs, query]);

  const filteredHandshakeLogs = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return handshakeLogs;
    return handshakeLogs.filter((log) =>
      [log.parcel_id, log.step, log.status]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(term))
    );
  }, [handshakeLogs, query]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Monitoring Logs"
        description="Search error events and handshake traces without leaving the console."
      />

      <div className="grid gap-4 md:grid-cols-4">
        <StatCard title="Error Logs" value={errorLogs.length} icon={Activity} color="red" />
        <StatCard title="Handshake Events" value={handshakeLogs.length} icon={ScrollText} color="teal" />
        <StatCard title="Devices" value={new Set(errorLogs.map((log) => log.device_model).filter(Boolean)).size} icon={HardDrive} color="slate" />
        <StatCard title="OS Versions" value={new Set(errorLogs.map((log) => log.os_version).filter(Boolean)).size} icon={Smartphone} color="amber" />
      </div>

      <Card>
        <CardHeader className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="micro-label">Log Search</p>
            <CardTitle>System Logs</CardTitle>
            <CardDescription>Filter by message, device, status, or parcel identifier.</CardDescription>
          </div>
          <div className="relative w-full md:max-w-md">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" size={16} />
            <Input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search logs..."
              className="pl-10"
            />
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex flex-wrap gap-2">
            <Button variant={tab === "errors" ? "default" : "outline"} onClick={() => setTab("errors")} size="sm">
              Error Logs
            </Button>
            <Button
              variant={tab === "handshake" ? "default" : "outline"}
              onClick={() => setTab("handshake")}
              size="sm"
            >
              Handshake Events
            </Button>
          </div>

          {loading ? (
            <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">
              Loading logs...
            </div>
          ) : tab === "errors" ? (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-white/10 text-left">
                    <th className="py-3 pr-4 font-medium text-slate-400">Message</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Device</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">OS</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Created</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredErrorLogs.map((log) => (
                    <tr key={log.id} className="border-b border-white/5 hover:bg-white/5">
                      <td className="py-3 pr-4">
                        <div className="max-w-xl truncate text-slate-100">{log.message}</div>
                        <div className="mt-1 max-w-xl truncate text-xs text-slate-500">{log.stack_trace}</div>
                      </td>
                      <td className="py-3 pr-4 text-slate-300">{log.device_model || "-"}</td>
                      <td className="py-3 pr-4 text-slate-300">{log.os_version || "-"}</td>
                      <td className="py-3 pr-4 text-slate-400">{new Date(log.created_at).toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {filteredErrorLogs.length === 0 && (
                <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 py-8 text-center text-sm text-slate-400">
                  No error logs found
                </div>
              )}
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-white/10 text-left">
                    <th className="py-3 pr-4 font-medium text-slate-400">Parcel</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Step</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Status</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Location</th>
                    <th className="py-3 pr-4 font-medium text-slate-400">Created</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredHandshakeLogs.map((log) => (
                    <tr key={log.id} className="border-b border-white/5 hover:bg-white/5">
                      <td className="py-3 pr-4 font-mono text-slate-200">{log.parcel_id}</td>
                      <td className="py-3 pr-4 text-slate-300">{log.step}</td>
                      <td className="py-3 pr-4">
                        <Badge variant="secondary">{log.status}</Badge>
                      </td>
                      <td className="py-3 pr-4 text-slate-400">
                        {log.lat.toFixed(4)}, {log.lng.toFixed(4)} • {log.accuracy_m}m
                      </td>
                      <td className="py-3 pr-4 text-slate-400">{new Date(log.created_at).toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {filteredHandshakeLogs.length === 0 && (
                <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 py-8 text-center text-sm text-slate-400">
                  No handshake events found
                </div>
              )}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
