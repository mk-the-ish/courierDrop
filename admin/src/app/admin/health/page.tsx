"use client";

import PageHeader from '@/components/page-header';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Activity } from 'lucide-react';

export default function HealthPage() {
  return (
    <div className="flex flex-col gap-8 p-8">
      <PageHeader
        title="System Health"
        description="Monitor system performance and job status"
      />
      
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Activity className="h-4 w-4" />
            Job Scheduler Status
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground">
            Real-time job scheduler information will appear here.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
