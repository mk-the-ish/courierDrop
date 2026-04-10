"use client";

import PageHeader from '@/components/page-header';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Settings } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

export default function SettingsPage() {
  return (
    <div className="flex flex-col gap-8 p-8">
      <PageHeader
        title="Settings"
        description="Configure system and notification settings"
      />
      
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Settings className="h-4 w-4" />
            System Configuration
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="api-url">API Base URL</Label>
            <Input
              id="api-url"
              placeholder="http://localhost:8080"
              defaultValue="http://localhost:8080"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="notification-email">Alert Notification Email</Label>
            <Input
              id="notification-email"
              type="email"
              placeholder="admin@example.com"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="slack-webhook">Slack Webhook URL (Optional)</Label>
            <Input
              id="slack-webhook"
              placeholder="https://hooks.slack.com/services/..."
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="sms-number">SMS Alert Number (Optional)</Label>
            <Input
              id="sms-number"
              placeholder="+1234567890"
            />
          </div>

          <Button>Save Settings</Button>
        </CardContent>
      </Card>
    </div>
  );
}
