"use client";

import { PageHeader } from '@/components/page-header';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Clock } from 'lucide-react';

export default function SchedulerPage() {
  return (
    <div className="flex flex-col gap-8 p-8">
      <PageHeader
        title="Job Scheduler"
        description="Manage and monitor background job execution"
      />
      
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Clock className="h-4 w-4" />
            Scheduled Jobs
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground">
            Scheduled jobs list and management interface coming soon.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
