"use client";

import { useState } from 'react';
import type { MatchLog as MatchLogType } from '@/lib/types';
import PageHeader from '@/components/dashboard/page-header';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';

type MatchLogProps = {
  logs: MatchLogType[];
};

export default function MatchLog({ logs }: MatchLogProps) {
  const [selectedLog, setSelectedLog] = useState<MatchLogType | null>(null);

  return (
    <div className="flex flex-col gap-8">
      <PageHeader title="Match Analysis Log" />
      <Card>
        <CardHeader>
          <CardTitle>Matching Service Logs</CardTitle>
          <CardDescription>
            Detailed logs for each courier-order match calculation.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Dialog>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Order ID</TableHead>
                  <TableHead>Courier</TableHead>
                  <TableHead>Detour Cost (km)</TableHead>
                  <TableHead>Match Score</TableHead>
                  <TableHead>Timestamp</TableHead>
                  <TableHead>Details</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {logs.map((log) => (
                  <TableRow key={log.orderId + log.courierId}>
                    <TableCell className="font-medium">{log.orderId}</TableCell>
                    <TableCell>
                      <div className="font-medium">{log.courierName}</div>
                      <div className="text-sm text-muted-foreground">{log.courierId}</div>
                    </TableCell>
                    <TableCell>{log.detourCost.toFixed(2)}</TableCell>
                    <TableCell>{log.matchScore.toFixed(4)}</TableCell>
                    <TableCell>{log.timestamp}</TableCell>
                    <TableCell>
                      <DialogTrigger asChild>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => setSelectedLog(log)}
                        >
                          View Raw
                        </Button>
                      </DialogTrigger>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            {selectedLog && (
              <DialogContent className="max-w-2xl">
                <DialogHeader>
                  <DialogTitle>Raw Match Results for {selectedLog.orderId}</DialogTitle>
                  <DialogDescription>
                    Courier: {selectedLog.courierName} ({selectedLog.courierId})
                  </DialogDescription>
                </DialogHeader>
                <div className="grid gap-4 py-4 text-sm">
                    <div className="grid grid-cols-[180px_1fr] items-center gap-4">
                        <span className="text-muted-foreground">Timestamp</span>
                        <span>{selectedLog.timestamp}</span>
                    </div>
                    <div className="grid grid-cols-[180px_1fr] items-center gap-4">
                        <span className="text-muted-foreground">Match Score</span>
                        <span className="font-mono font-bold">{selectedLog.matchScore.toFixed(4)}</span>
                    </div>
                    <div className="grid grid-cols-[180px_1fr] items-center gap-4">
                        <span className="text-muted-foreground">Detour Cost</span>
                        <span className="font-mono">{selectedLog.detourCost.toFixed(2)} km</span>
                    </div>
                    <div className="grid grid-cols-[180px_1fr] items-center gap-4">
                        <span className="text-muted-foreground">Courier Location</span>
                        <span className="font-mono">{selectedLog.rawResults.courierLocation.join(', ')}</span>
                    </div>
                    <div className="grid grid-cols-[180px_1fr] items-center gap-4">
                        <span className="text-muted-foreground">Pickup Location</span>
                        <span className="font-mono">{selectedLog.rawResults.pickupLocation.join(', ')}</span>
                    </div>
                    <div className="grid grid-cols-[180px_1fr] items-center gap-4">
                        <span className="text-muted-foreground">Dropoff Location</span>
                        <span className="font-mono">{selectedLog.rawResults.dropoffLocation.join(', ')}</span>
                    </div>
                    <div className="grid grid-cols-[180px_1fr] items-center gap-4">
                        <span className="text-muted-foreground">Courier Reputation</span>
                        <span className="font-mono">{selectedLog.rawResults.courierReputation.toFixed(3)}</span>
                    </div>
                     <div className="grid grid-cols-[180px_1fr] items-start gap-4">
                        <span className="text-muted-foreground">Final Score Breakdown</span>
                        <code className="relative rounded bg-muted px-[0.3rem] py-[0.2rem] font-mono text-sm">
                            {selectedLog.rawResults.finalScoreBreakdown}
                        </code>
                    </div>
                </div>
              </DialogContent>
            )}
          </Dialog>
        </CardContent>
      </Card>
    </div>
  );
}
