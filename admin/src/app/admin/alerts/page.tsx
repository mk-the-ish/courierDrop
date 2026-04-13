"use client";

import { useState, useEffect, type FormEvent } from 'react';
import { AlertCircle, Edit2, Trash2, Plus } from 'lucide-react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  FormControl,
  FormItem,
  FormLabel,
} from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectOption,
} from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';
import { PageHeader } from '@/components/page-header';
import { useToast } from '@/hooks/use-toast';

const baseUrl = 'http://localhost:8080';

type AlertRule = {
  id: string;
  name: string;
  metric: string;
  operator: string;
  threshold: number;
  notification_channel: string;
};

type AlertRuleForm = Omit<AlertRule, 'id'>;

export default function AlertsPage() {
  const [rules, setRules] = useState<AlertRule[]>([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formData, setFormData] = useState<AlertRuleForm>({
    name: '',
    metric: 'uptime',
    operator: 'less_than',
    threshold: 80,
    notification_channel: 'email',
  });
  const { toast } = useToast();

  useEffect(() => {
    fetchRules();
  }, []);

  const fetchRules = async () => {
    try {
      const token = localStorage.getItem('adminToken');
      const res = await fetch(`${baseUrl}/admin/alerts/rules`, {
        headers: token ? { 'Authorization': `Bearer ${token}` } : {},
      });
      const data = await res.json();
      setRules(data.rules || []);
    } catch (error) {
      console.error('Error fetching rules:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
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
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify(formData),
      });

      if (res.ok) {
        toast({
          title: 'Success',
          description: editingId ? 'Rule updated' : 'Rule created',
        });
        fetchRules();
        resetForm();
        setOpen(false);
      }
    } catch (error) {
      console.error('Error saving rule:', error);
      toast({
        title: 'Error',
        description: 'Failed to save rule',
        variant: 'destructive',
      });
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this rule?')) return;
    try {
      const token = localStorage.getItem('adminToken');
      await fetch(`${baseUrl}/admin/alerts/rules/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` },
      });
      toast({
        title: 'Success',
        description: 'Rule deleted',
      });
      fetchRules();
    } catch (error) {
      console.error('Error deleting rule:', error);
      toast({
        title: 'Error',
        description: 'Failed to delete rule',
        variant: 'destructive',
      });
    }
  };

  const resetForm = () => {
    setEditingId(null);
    setFormData({
      name: '',
      metric: 'uptime',
      operator: 'less_than',
      threshold: 80,
      notification_channel: 'email',
    });
  };

  const handleEdit = (rule: AlertRule) => {
    setFormData({
      name: rule.name,
      metric: rule.metric,
      operator: rule.operator,
      threshold: rule.threshold,
      notification_channel: rule.notification_channel,
    });
    setEditingId(rule.id);
    setOpen(true);
  };

  return (
    <div className="flex flex-col gap-8 p-8">
      <div className="flex items-center justify-between">
        <PageHeader 
          title="Alert Rules" 
          description="Manage system alerts and notifications"
        />
        <Dialog open={open} onOpenChange={setOpen}>
          <Button
            onClick={() => {
              resetForm();
              setOpen(true);
            }}
          >
            <Plus className="mr-2 h-4 w-4" />
            Create Rule
          </Button>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>
                {editingId ? 'Edit Alert Rule' : 'Create Alert Rule'}
              </DialogTitle>
              <DialogDescription>
                Set up a new alert rule to monitor system metrics
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleSubmit} className="space-y-4">
              <FormItem>
                <FormLabel>Rule Name</FormLabel>
                <FormControl>
                  <Input
                    placeholder="e.g., Low Uptime Alert"
                    value={formData.name}
                    onChange={(e) =>
                      setFormData({ ...formData, name: e.target.value })
                    }
                    required
                  />
                </FormControl>
              </FormItem>

              <FormItem>
              <FormLabel>Metric</FormLabel>
              <Select
                value={formData.metric}
                onChange={(e) =>
                  setFormData({ ...formData, metric: e.target.value })
                }
              >
                <SelectOption value="uptime">Uptime</SelectOption>
                <SelectOption value="error_rate">Error Rate</SelectOption>
                <SelectOption value="response_time">Response Time</SelectOption>
                <SelectOption value="job_failures">Job Failures</SelectOption>
              </Select>
            </FormItem>

              <FormItem>
              <FormLabel>Condition</FormLabel>
              <Select
                value={formData.operator}
                onChange={(e) =>
                  setFormData({ ...formData, operator: e.target.value })
                }
              >
                <SelectOption value="less_than">Less than</SelectOption>
                <SelectOption value="greater_than">Greater than</SelectOption>
                <SelectOption value="equal">Equal to</SelectOption>
              </Select>
            </FormItem>

              <FormItem>
                <FormLabel>Threshold</FormLabel>
                <FormControl>
                  <Input
                    type="number"
                    value={formData.threshold}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        threshold: parseFloat(e.target.value),
                      })
                    }
                    required
                  />
                </FormControl>
              </FormItem>

              <FormItem>
              <FormLabel>Notification Channel</FormLabel>
              <Select
                value={formData.notification_channel}
                onChange={(e) =>
                  setFormData({
                    ...formData,
                    notification_channel: e.target.value,
                  })
                }
              >
                <SelectOption value="email">Email</SelectOption>
                <SelectOption value="slack">Slack</SelectOption>
                <SelectOption value="webhook">Webhook</SelectOption>
              </Select>
            </FormItem>

              <div className="flex gap-2 justify-end">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setOpen(false)}
                >
                  Cancel
                </Button>
                <Button type="submit">
                  {editingId ? 'Update Rule' : 'Create Rule'}
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-96">
          <div className="text-center">
            <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-muted-foreground">Loading alert rules...</p>
          </div>
        </div>
      ) : (
        <div className="grid gap-4">
          {rules.length === 0 ? (
            <Card>
              <CardContent className="pt-6">
                <div className="flex flex-col items-center justify-center text-center py-8">
                  <AlertCircle className="h-12 w-12 text-muted-foreground mb-4" />
                  <p className="text-muted-foreground">No alert rules configured</p>
                </div>
              </CardContent>
            </Card>
          ) : (
            rules.map((rule) => (
              <Card key={rule.id}>
                <CardHeader className="flex flex-row items-start justify-between space-y-0">
                  <div>
                    <CardTitle>{rule.name}</CardTitle>
                  </div>
                  <div className="flex gap-2">
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => handleEdit(rule)}
                    >
                      <Edit2 className="h-4 w-4" />
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => handleDelete(rule.id)}
                    >
                      <Trash2 className="h-4 w-4 text-destructive" />
                    </Button>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="grid gap-2 text-sm">
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Metric:</span>
                      <Badge variant="outline">{rule.metric}</Badge>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Condition:</span>
                      <Badge variant="outline">{rule.operator}</Badge>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Threshold:</span>
                      <Badge variant="outline">{rule.threshold}</Badge>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Channel:</span>
                      <Badge variant="outline">
                        {rule.notification_channel}
                      </Badge>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))
          )}
        </div>
      )}
    </div>
  );
}
