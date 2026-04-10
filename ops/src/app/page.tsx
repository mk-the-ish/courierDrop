import {
  Activity,
  Briefcase,
  Clock,
  Users,
} from 'lucide-react';
import {
  Card,
  CardContent,
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
import { Badge } from '@/components/ui/badge';
import StatCard from '@/components/dashboard/stat-card';
import PageHeader from '@/components/dashboard/page-header';
import { jobs, couriers } from '@/lib/data';
import type { Job } from '@/lib/types';

export default function Home() {
  const activeJobs = jobs.filter((job) => job.status === 'in-progress').length;
  const pendingMatches = jobs.filter((job) => job.status === 'pending').length;
  const onlineCouriers = couriers.filter(
    (courier) => courier.courierStatus === 'on-duty'
  ).length;

  const recentJobs = jobs.slice(0, 5);

  const getStatusVariant = (status: Job['status']) => {
    switch (status) {
      case 'completed':
        return 'default';
      case 'in-progress':
        return 'secondary';
      case 'pending':
        return 'outline';
      case 'cancelled':
        return 'destructive';
      default:
        return 'default';
    }
  };

  return (
    <div className="flex flex-col gap-8">
      <PageHeader title="Operational Overview" />
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <StatCard
          title="Active Jobs"
          value={activeJobs}
          icon={<Briefcase className="h-4 w-4 text-muted-foreground" />}
          description="Jobs currently in progress"
        />
        <StatCard
          title="Pending Matches"
          value={pendingMatches}
          icon={<Clock className="h-4 w-4 text-muted-foreground" />}
          description="Jobs awaiting courier assignment"
        />
        <StatCard
          title="Couriers Online"
          value={onlineCouriers}
          icon={<Users className="h-4 w-4 text-muted-foreground" />}
          description="Couriers currently on-duty"
        />
      </div>

      <div className="grid grid-cols-1 gap-8">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Activity className="h-5 w-5" />
              Recent Job Activity
            </CardTitle>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Job ID</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Courier ID</TableHead>
                  <TableHead>Last Update</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {recentJobs.map((job) => (
                  <TableRow key={job.id}>
                    <TableCell className="font-medium">{job.id}</TableCell>
                    <TableCell>
                      <Badge variant={getStatusVariant(job.status)}>
                        {job.status}
                      </Badge>
                    </TableCell>
                    <TableCell>{job.courierId || 'N/A'}</TableCell>
                    <TableCell>{job.lastReportedAt}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
