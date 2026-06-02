"use client";

import { useEffect, useMemo, useState } from "react";
import { AlertCircle, Bell, Mail, Plus, Trash2, Edit2 } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import StatCard from "@/components/StatCard";
import { getApiBaseUrl } from "@/lib/api-base-url";

const baseUrl = getApiBaseUrl();

interface AlertRule {
  id: string;
  name: string;
  condition_type: string;
  condition_value: number;
  notification_channel: string;
  recipient: string;
  is_active: boolean;
  created_at: string;
}

const conditionTypes = [
  { value: "delivery_time_exceeded", label: "Delivery Time Exceeded (minutes)" },
  { value: "offline_courier", label: "Courier Offline (minutes)" },
  { value: "low_rating", label: "Low Rating (score)" },
  { value: "failed_handshake", label: "Failed Handshake Detection" },
  { value: "gps_gate_violation", label: "GPS Gate Violation" },
];

const notificationChannels = [
  { value: "sms", label: "SMS", icon: Bell },
  { value: "email", label: "Email", icon: Mail },
];

export default function AlertsPage() {
  const [rules, setRules] = useState<AlertRule[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    name: "",
    condition_type: "delivery_time_exceeded",
    condition_value: 30,
    notification_channel: "sms",
    recipient: "",
    is_active: true,
  });
  const [editingId, setEditingId] = useState<string | null>(null);

  const getToken = () => localStorage.getItem("admin_token") || localStorage.getItem("adminToken") || "";

  const loadRules = async () => {
    setLoading(true);
    setError(null);
    try {
      const token = getToken();
      if (!token) throw new Error("Not authenticated");

      const res = await fetch(`${baseUrl}/admin/alerts/rules`, {
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      });

      if (!res.ok) {
        if (res.status === 404) {
          setRules([]);
          return;
        }
        throw new Error(`Failed to load alert rules: ${res.status}`);
      }

      const data = await res.json();
      setRules(data.rules || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load alert rules");
    } finally {
      setLoading(false);
    }
  };

  const saveRule = async () => {
    if (!formData.name || !formData.recipient) {
      setError("Please fill in all fields");
      return;
    }

    try {
      const token = getToken();
      if (!token) throw new Error("Not authenticated");

      const url = editingId ? `${baseUrl}/admin/alerts/rules/${editingId}` : `${baseUrl}/admin/alerts/rules`;
      const method = editingId ? "PATCH" : "POST";

      const res = await fetch(url, {
        method,
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify(formData),
      });

      if (!res.ok) throw new Error(`Failed to save rule: ${res.status}`);

      await loadRules();
      setShowForm(false);
      setEditingId(null);
      setFormData({
        name: "",
        condition_type: "delivery_time_exceeded",
        condition_value: 30,
        notification_channel: "sms",
        recipient: "",
        is_active: true,
      });
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save rule");
    }
  };

  const deleteRule = async (id: string) => {
    if (!confirm("Are you sure you want to delete this rule?")) return;

    try {
      const token = getToken();
      if (!token) throw new Error("Not authenticated");

      const res = await fetch(`${baseUrl}/admin/alerts/rules/${id}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      });

      if (!res.ok) throw new Error(`Failed to delete rule: ${res.status}`);
      await loadRules();
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete rule");
    }
  };

  const editRule = (rule: AlertRule) => {
    setFormData({
      name: rule.name,
      condition_type: rule.condition_type,
      condition_value: rule.condition_value,
      notification_channel: rule.notification_channel,
      recipient: rule.recipient,
      is_active: rule.is_active,
    });
    setEditingId(rule.id);
    setShowForm(true);
  };

  useEffect(() => {
    loadRules();
  }, []);

  const activeCount = useMemo(() => rules.filter((rule) => rule.is_active).length, [rules]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Alert Rules"
        description="Configure automated delivery alerts and notifications in a compact, glanceable control surface."
        action={
          <Button
            onClick={() => {
              setShowForm(!showForm);
              setEditingId(null);
              setFormData({
                name: "",
                condition_type: "delivery_time_exceeded",
                condition_value: 30,
                notification_channel: "sms",
                recipient: "",
                is_active: true,
              });
            }}
          >
            <Plus className="mr-2 h-4 w-4" />
            New Rule
          </Button>
        }
      />

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard title="Total Rules" value={rules.length} color="teal" />
        <StatCard title="Active Rules" value={activeCount} color="green" />
        <StatCard title="Paused Rules" value={rules.length - activeCount} color="amber" />
      </div>

      {error && (
        <div className="flex gap-3 rounded-2xl border border-rose-500/20 bg-rose-500/10 p-4 text-sm text-rose-200">
          <AlertCircle className="mt-0.5 h-5 w-5 flex-shrink-0 text-rose-300" />
          <p>{error}</p>
        </div>
      )}

      {showForm && (
        <Card>
          <CardHeader>
            <p className="micro-label">{editingId ? "Edit Rule" : "Create Rule"}</p>
            <CardTitle>{editingId ? "Edit Alert Rule" : "Create Alert Rule"}</CardTitle>
            <CardDescription>
              Define the trigger and route the notification to the correct recipient channel.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2 md:col-span-2">
                <label className="block text-sm font-medium text-slate-300">Rule Name</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="e.g., High Delivery Time Alert"
                  className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-slate-100 placeholder:text-slate-500 focus:border-orange-accent focus:outline-none"
                />
              </div>

              <div className="space-y-2">
                <label className="block text-sm font-medium text-slate-300">Condition Type</label>
                <select
                  value={formData.condition_type}
                  onChange={(e) => setFormData({ ...formData, condition_type: e.target.value })}
                  className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-slate-100 focus:border-orange-accent focus:outline-none"
                >
                  {conditionTypes.map((conditionType) => (
                    <option key={conditionType.value} value={conditionType.value}>
                      {conditionType.label}
                    </option>
                  ))}
                </select>
              </div>

              <div className="space-y-2">
                <label className="block text-sm font-medium text-slate-300">Threshold Value</label>
                <input
                  type="number"
                  value={formData.condition_value}
                  onChange={(e) => setFormData({ ...formData, condition_value: parseInt(e.target.value) })}
                  placeholder="30"
                  className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-slate-100 placeholder:text-slate-500 focus:border-orange-accent focus:outline-none"
                />
              </div>

              <div className="space-y-2">
                <label className="block text-sm font-medium text-slate-300">Notification Channel</label>
                <select
                  value={formData.notification_channel}
                  onChange={(e) => setFormData({ ...formData, notification_channel: e.target.value })}
                  className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-slate-100 focus:border-orange-accent focus:outline-none"
                >
                  {notificationChannels.map((channel) => (
                    <option key={channel.value} value={channel.value}>
                      {channel.label}
                    </option>
                  ))}
                </select>
              </div>

              <div className="space-y-2">
                <label className="block text-sm font-medium text-slate-300">Recipient (Phone/Email)</label>
                <input
                  type="text"
                  value={formData.recipient}
                  onChange={(e) => setFormData({ ...formData, recipient: e.target.value })}
                  placeholder="+1234567890"
                  className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-slate-100 placeholder:text-slate-500 focus:border-orange-accent focus:outline-none"
                />
              </div>
            </div>

            <div className="flex items-center gap-3 rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
              <input
                type="checkbox"
                id="is_active"
                checked={formData.is_active}
                onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                className="h-4 w-4 rounded border-white/20 bg-white/5 text-orange-accent"
              />
              <label htmlFor="is_active" className="text-sm font-medium text-slate-300">
                Rule is active
              </label>
            </div>

            <div className="flex gap-3 pt-2">
              <Button onClick={saveRule}>{editingId ? "Update Rule" : "Create Rule"}</Button>
              <Button
                variant="outline"
                onClick={() => {
                  setShowForm(false);
                  setEditingId(null);
                }}
              >
                Cancel
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader>
          <p className="micro-label">Rules Library</p>
          <CardTitle>Active Rules</CardTitle>
          <CardDescription>Manage the operational alert set used by the logistics stack.</CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">
              Loading alert rules...
            </div>
          ) : rules.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-6 text-sm text-slate-400">
              No alert rules found.
            </div>
          ) : (
            <div className="space-y-3">
              {rules.map((rule) => (
                <div
                  key={rule.id}
                  className="flex flex-col gap-4 rounded-2xl border border-white/10 bg-white/5 p-4 md:flex-row md:items-center md:justify-between"
                >
                  <div>
                    <div className="flex items-center gap-2">
                      <h3 className="font-semibold text-slate-100">{rule.name}</h3>
                      <Badge variant={rule.is_active ? "success" : "secondary"}>
                        {rule.is_active ? "Active" : "Paused"}
                      </Badge>
                    </div>
                    <p className="mt-1 text-sm text-slate-400">
                      {conditionTypes.find((type) => type.value === rule.condition_type)?.label || rule.condition_type} •
                      {rule.condition_value} • {rule.notification_channel?.toUpperCase?.() ?? "UNKNOWN"} → {rule.recipient}
                    </p>
                  </div>
                  <div className="flex gap-2">
                    <Button variant="outline" size="sm" onClick={() => editRule(rule)}>
                      <Edit2 className="mr-2 h-4 w-4" />
                      Edit
                    </Button>
                    <Button variant="outline" size="sm" onClick={() => deleteRule(rule.id)}>
                      <Trash2 className="mr-2 h-4 w-4" />
                      Delete
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
