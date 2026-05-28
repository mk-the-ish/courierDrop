'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { AlertCircle, Plus, Trash2, Edit2, Bell, Mail } from 'lucide-react';

const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8080';

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
  { value: 'delivery_time_exceeded', label: 'Delivery Time Exceeded (minutes)' },
  { value: 'offline_courier', label: 'Courier Offline (minutes)' },
  { value: 'low_rating', label: 'Low Rating (score)' },
  { value: 'failed_handshake', label: 'Failed Handshake Detection' },
  { value: 'gps_gate_violation', label: 'GPS Gate Violation' }
];

const notificationChannels = [
  { value: 'sms', label: 'SMS', icon: Bell },
  { value: 'email', label: 'Email', icon: Mail }
];

export default function AlertsPage() {
  const [rules, setRules] = useState<AlertRule[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    condition_type: 'delivery_time_exceeded',
    condition_value: 30,
    notification_channel: 'sms',
    recipient: '',
    is_active: true
  });
  const [editingId, setEditingId] = useState<string | null>(null);

  const getToken = () => {
    return localStorage.getItem('admin_token') || localStorage.getItem('adminToken') || '';
  };

  const loadRules = async () => {
    setLoading(true);
    setError(null);
    try {
      const token = getToken();
      if (!token) throw new Error('Not authenticated');

      const res = await fetch(`${baseUrl}/admin/alerts/rules`, {
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }
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
      setError(err instanceof Error ? err.message : 'Failed to load alert rules');
    } finally {
      setLoading(false);
    }
  };

  const saveRule = async () => {
    if (!formData.name || !formData.recipient) {
      setError('Please fill in all fields');
      return;
    }

    try {
      const token = getToken();
      if (!token) throw new Error('Not authenticated');

      const url = editingId
        ? `${baseUrl}/admin/alerts/rules/${editingId}`
        : `${baseUrl}/admin/alerts/rules`;

      const method = editingId ? 'PATCH' : 'POST';

      const res = await fetch(url, {
        method,
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });

      if (!res.ok) {
        throw new Error(`Failed to save rule: ${res.status}`);
      }

      await loadRules();
      setShowForm(false);
      setEditingId(null);
      setFormData({
        name: '',
        condition_type: 'delivery_time_exceeded',
        condition_value: 30,
        notification_channel: 'sms',
        recipient: '',
        is_active: true
      });
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save rule');
    }
  };

  const deleteRule = async (id: string) => {
    if (!confirm('Are you sure you want to delete this rule?')) return;

    try {
      const token = getToken();
      if (!token) throw new Error('Not authenticated');

      const res = await fetch(`${baseUrl}/admin/alerts/rules/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }
      });

      if (!res.ok) {
        throw new Error(`Failed to delete rule: ${res.status}`);
      }

      await loadRules();
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete rule');
    }
  };

  const editRule = (rule: AlertRule) => {
    setFormData({
      name: rule.name,
      condition_type: rule.condition_type,
      condition_value: rule.condition_value,
      notification_channel: rule.notification_channel,
      recipient: rule.recipient,
      is_active: rule.is_active
    });
    setEditingId(rule.id);
    setShowForm(true);
  };

  useEffect(() => {
    loadRules();
  }, []);

  const conditionTypeLabel = conditionTypes.find(t => t.value === formData.condition_type)?.label || '';

  return (
    <div className="space-y-8 p-8">
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-4xl font-bold text-white mb-2">Alert Rules</h1>
          <p className="text-slate-400">Configure automated delivery alerts and notifications</p>
        </div>
        <Button
          onClick={() => {
            setShowForm(!showForm);
            setEditingId(null);
            setFormData({
              name: '',
              condition_type: 'delivery_time_exceeded',
              condition_value: 30,
              notification_channel: 'sms',
              recipient: '',
              is_active: true
            });
          }}
          className="bg-blue-600 hover:bg-blue-700 text-white"
        >
          <Plus className="w-4 h-4 mr-2" />
          New Rule
        </Button>
      </div>

      {error && (
        <div className="flex gap-2 p-4 bg-red-500/10 border border-red-500/20 rounded-lg">
          <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
          <p className="text-red-400 text-sm">{error}</p>
        </div>
      )}

      {/* Form */}
      {showForm && (
        <Card className="bg-slate-800 border-slate-700">
          <CardHeader>
            <CardTitle className="text-white">
              {editingId ? 'Edit Alert Rule' : 'Create Alert Rule'}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">Rule Name</label>
              <input
                type="text"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="e.g., High Delivery Time Alert"
                className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white placeholder-slate-500 focus:border-blue-500 focus:outline-none"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">Condition Type</label>
                <select
                  value={formData.condition_type}
                  onChange={(e) => setFormData({ ...formData, condition_type: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white focus:border-blue-500 focus:outline-none"
                >
                  {conditionTypes.map(ct => (
                    <option key={ct.value} value={ct.value}>{ct.label}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">Threshold Value</label>
                <input
                  type="number"
                  value={formData.condition_value}
                  onChange={(e) => setFormData({ ...formData, condition_value: parseInt(e.target.value) })}
                  placeholder="30"
                  className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white placeholder-slate-500 focus:border-blue-500 focus:outline-none"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">Notification Channel</label>
                <select
                  value={formData.notification_channel}
                  onChange={(e) => setFormData({ ...formData, notification_channel: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white focus:border-blue-500 focus:outline-none"
                >
                  {notificationChannels.map(nc => (
                    <option key={nc.value} value={nc.value}>{nc.label}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">Recipient (Phone/Email)</label>
                <input
                  type="text"
                  value={formData.recipient}
                  onChange={(e) => setFormData({ ...formData, recipient: e.target.value })}
                  placeholder="+1234567890"
                  className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-white placeholder-slate-500 focus:border-blue-500 focus:outline-none"
                />
              </div>
            </div>

            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="is_active"
                checked={formData.is_active}
                onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                className="w-4 h-4 rounded bg-slate-700 border-slate-600 text-blue-600"
              />
              <label htmlFor="is_active" className="text-sm font-medium text-slate-300">
                Rule is Active
              </label>
            </div>

            <div className="flex gap-3 pt-4">
              <Button
                onClick={saveRule}
                className="bg-blue-600 hover:bg-blue-700 text-white"
              >
                {editingId ? 'Update Rule' : 'Create Rule'}
              </Button>
              <Button
                onClick={() => {
                  setShowForm(false);
                  setEditingId(null);
                }}
                variant="outline"
                className="bg-slate-700 border-slate-600 text-white hover:bg-slate-600"
              >
                Cancel
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Rules List */}
      <Card className="bg-slate-800 border-slate-700">
        <CardHeader>
          <CardTitle className="text-white">Active Rules ({rules.length})</CardTitle>
          <CardDescription className="text-slate-400">Manage your alert rules</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {rules.map(rule => (
              <div key={rule.id} className="p-4 bg-slate-700 rounded-lg border border-slate-600 flex justify-between items-start">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="font-medium text-white">{rule.name}</h3>
                    {rule.is_active ? (
                      <Badge className="bg-green-500/20 text-green-400 border-0">Active</Badge>
                    ) : (
                      <Badge className="bg-slate-600 text-slate-300 border-0">Inactive</Badge>
                    )}
                  </div>
                  <p className="text-sm text-slate-300">
                    {conditionTypes.find(t => t.value === rule.condition_type)?.label} {rule.condition_type === 'failed_handshake' ? '' : `≥ ${rule.condition_value}`}
                  </p>
                  <p className="text-xs text-slate-400 mt-2">
                    Notify via {rule.notification_channel.toUpperCase()} to {rule.recipient}
                  </p>
                </div>
                <div className="flex gap-2">
                  <Button
                    onClick={() => editRule(rule)}
                    size="sm"
                    variant="outline"
                    className="bg-slate-600 border-slate-500 text-slate-200 hover:bg-slate-500"
                  >
                    <Edit2 className="w-4 h-4" />
                  </Button>
                  <Button
                    onClick={() => deleteRule(rule.id)}
                    size="sm"
                    variant="outline"
                    className="bg-red-500/10 border-red-500/20 text-red-400 hover:bg-red-500/20"
                  >
                    <Trash2 className="w-4 h-4" />
                  </Button>
                </div>
              </div>
            ))}
          </div>
          {rules.length === 0 && (
            <div className="text-center py-8 text-slate-400">
              No alert rules configured. Create one to get started.
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
