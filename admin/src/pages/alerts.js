import { useState, useEffect } from 'react';
import DashboardHeader from '../components/DashboardHeader';
import { AlertCircle, Trash2, Edit2 } from 'lucide-react';

const baseUrl = 'http://localhost:8080';

export default function AlertRules() {
  const [rules, setRules] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    metric: 'uptime',
    operator: 'less_than',
    threshold: 80,
    notification_channel: 'email'
  });

  useEffect(() => {
    fetchRules();
  }, []);

  const fetchRules = async () => {
    try {
      const token = localStorage.getItem('adminToken');
      const res = await fetch(`${baseUrl}/admin/alerts/rules`, {
        headers: token ? { 'Authorization': `Bearer ${token}` } : {}
      });
      const data = await res.json();
      setRules(data.rules || []);
    } catch (error) {
      console.error('Error fetching rules:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('adminToken');
      const method = editingId ? 'PATCH' : 'POST';
      const url = editingId
        ? `${baseUrl}/admin/alerts/rules/${editingId}`
        : `${baseUrl}/admin/alerts/rules`;

      const res = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(formData)
      });

      if (res.ok) {
        fetchRules();
        resetForm();
      }
    } catch (error) {
      console.error('Error saving rule:', error);
    }
  };

  const handleDelete = async (id) => {
    if (!confirm('Delete this rule?')) return;
    try {
      const token = localStorage.getItem('adminToken');
      await fetch(`${baseUrl}/admin/alerts/rules/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      fetchRules();
    } catch (error) {
      console.error('Error deleting rule:', error);
    }
  };

  const resetForm = () => {
    setShowForm(false);
    setEditingId(null);
    setFormData({
      name: '',
      metric: 'uptime',
      operator: 'less_than',
      threshold: 80,
      notification_channel: 'email'
    });
  };

  const handleEdit = (rule) => {
    setFormData(rule);
    setEditingId(rule.id);
    setShowForm(true);
  };

  return (
    <div>
      <DashboardHeader
        title="Alert Rules"
        subtitle="Manage system alerts and notifications"
        actions={
          <button
            onClick={() => setShowForm(!showForm)}
            className="btn-primary"
          >
            {showForm ? 'Cancel' : '+ Create Rule'}
          </button>
        }
      />

      {showForm && (
        <div className="card p-6 mb-6">
          <h3 className="text-lg font-bold mb-4">
            {editingId ? 'Edit Rule' : 'New Alert Rule'}
          </h3>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-semibold text-slate-900 mb-2">
                  Rule Name
                </label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) =>
                    setFormData({ ...formData, name: e.target.value })
                  }
                  placeholder="e.g., Low Uptime Alert"
                  className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-semibold text-slate-900 mb-2">
                  Metric
                </label>
                <select
                  value={formData.metric}
                  onChange={(e) =>
                    setFormData({ ...formData, metric: e.target.value })
                  }
                  className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                >
                  <option value="uptime">Uptime</option>
                  <option value="error_rate">Error Rate</option>
                  <option value="response_time">Response Time</option>
                  <option value="job_failures">Job Failures</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-semibold text-slate-900 mb-2">
                  Condition
                </label>
                <select
                  value={formData.operator}
                  onChange={(e) =>
                    setFormData({ ...formData, operator: e.target.value })
                  }
                  className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                >
                  <option value="less_than">Less than</option>
                  <option value="greater_than">Greater than</option>
                  <option value="equal">Equal to</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-semibold text-slate-900 mb-2">
                  Threshold
                </label>
                <input
                  type="number"
                  value={formData.threshold}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      threshold: parseFloat(e.target.value)
                    })
                  }
                  className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                  required
                />
              </div>
              <div className="md:col-span-2">
                <label className="block text-sm font-semibold text-slate-900 mb-2">
                  Notification Channel
                </label>
                <select
                  value={formData.notification_channel}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      notification_channel: e.target.value
                    })
                  }
                  className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                >
                  <option value="email">Email</option>
                  <option value="slack">Slack</option>
                  <option value="webhook">Webhook</option>
                </select>
              </div>
            </div>
            <button type="submit" className="btn-primary">
              {editingId ? 'Update Rule' : 'Create Rule'}
            </button>
          </form>
        </div>
      )}

      <div className="grid grid-cols-1 gap-4">
        {rules.length === 0 ? (
          <div className="card p-8 text-center">
            <AlertCircle className="w-12 h-12 text-slate-300 mx-auto mb-4" />
            <p className="text-slate-600">No alert rules configured</p>
          </div>
        ) : (
          rules.map((rule) => (
            <div key={rule.id} className="card p-6">
              <div className="flex items-center justify-between">
                <div className="flex-1">
                  <h3 className="text-lg font-bold text-slate-900">
                    {rule.name}
                  </h3>
                  <div className="flex gap-4 mt-2 text-sm text-slate-600">
                    <span>Metric: <strong>{rule.metric}</strong></span>
                    <span>Condition: <strong>{rule.operator}</strong></span>
                    <span>Threshold: <strong>{rule.threshold}</strong></span>
                    <span>Channel: <strong>{rule.notification_channel}</strong></span>
                  </div>
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={() => handleEdit(rule)}
                    className="p-2 hover:bg-blue-50 rounded-lg text-blue-600"
                  >
                    <Edit2 className="w-5 h-5" />
                  </button>
                  <button
                    onClick={() => handleDelete(rule.id)}
                    className="p-2 hover:bg-red-50 rounded-lg text-red-600"
                  >
                    <Trash2 className="w-5 h-5" />
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
