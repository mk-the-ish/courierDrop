"use client";

import { useState } from 'react';
import type { Courier } from '@/lib/types';
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
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Button } from '@/components/ui/button';
import {
  ArrowUpDown,
  BarChart,
  MoreHorizontal,
} from 'lucide-react';
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  ChartLegend,
  ChartLegendContent,
} from '@/components/ui/chart';
import { Bar, BarChart as RechartsBarChart, XAxis, YAxis, CartesianGrid } from 'recharts';

type CourierDataProps = {
  couriers: Courier[];
};

type SortKey = keyof Pick<
  Courier,
  'name' | 'averageRating' | 'jobsCompleted' | 'acceptanceRate'
>;

export default function CourierData({ couriers: initialCouriers }: CourierDataProps) {
  const [couriers, setCouriers] = useState<Courier[]>(initialCouriers);
  const [sortConfig, setSortConfig] = useState<{
    key: SortKey;
    direction: 'asc' | 'desc';
  } | null>(null);

  const handleSort = (key: SortKey) => {
    let direction: 'asc' | 'desc' = 'asc';
    if (
      sortConfig &&
      sortConfig.key === key &&
      sortConfig.direction === 'asc'
    ) {
      direction = 'desc';
    }
    setSortConfig({ key, direction });

    const sortedCouriers = [...couriers].sort((a, b) => {
      if (a[key] < b[key]) return direction === 'asc' ? -1 : 1;
      if (a[key] > b[key]) return direction === 'asc' ? 1 : -1;
      return 0;
    });
    setCouriers(sortedCouriers);
  };

  const getStatusVariant = (status: Courier['courierStatus']) => {
    switch (status) {
      case 'on-duty':
        return 'default';
      case 'off-duty':
        return 'secondary';
      case 'active':
        return 'outline';
      case 'inactive':
        return 'destructive';
      default:
        return 'default';
    }
  };
  
  const chartData = couriers.slice(0, 5).map(c => ({
      name: c.name,
      completed: c.jobsCompleted,
      average: c.historicalAverage.jobs
  }));
  
  const chartConfig = {
      completed: {
          label: "Jobs Completed",
          color: "hsl(var(--primary))",
      },
      average: {
          label: "Historical Average",
          color: "hsl(var(--accent))",
      }
  }

  return (
    <div className="flex flex-col gap-8">
      <PageHeader title="Courier Performance" />
      <div className="grid gap-8 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>All Couriers</CardTitle>
            <CardDescription>
              Ranked list of all couriers on the platform.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Courier</TableHead>
                  <TableHead>
                    <Button
                      variant="ghost"
                      onClick={() => handleSort('averageRating')}
                    >
                      Avg. Rating
                      <ArrowUpDown className="ml-2 h-4 w-4" />
                    </Button>
                  </TableHead>
                  <TableHead>
                    <Button
                      variant="ghost"
                      onClick={() => handleSort('jobsCompleted')}
                    >
                      Jobs Done
                      <ArrowUpDown className="ml-2 h-4 w-4" />
                    </Button>
                  </TableHead>
                   <TableHead>
                    <Button
                      variant="ghost"
                      onClick={() => handleSort('acceptanceRate')}
                    >
                      Accept. Rate
                      <ArrowUpDown className="ml-2 h-4 w-4" />
                    </Button>
                  </TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {couriers.map((courier) => (
                  <TableRow key={courier.id}>
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <Avatar>
                          <AvatarImage src={courier.avatarUrl} />
                          <AvatarFallback>
                            {courier.name.charAt(0)}
                          </AvatarFallback>
                        </Avatar>
                        <div>
                          <p className="font-medium">{courier.name}</p>
                          <p className="text-sm text-muted-foreground">
                            {courier.id}
                          </p>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell>{courier.averageRating.toFixed(2)}</TableCell>
                    <TableCell>{courier.jobsCompleted}</TableCell>
                    <TableCell>{courier.acceptanceRate}%</TableCell>
                    <TableCell>
                      <Badge variant={getStatusVariant(courier.courierStatus)}>
                        {courier.courierStatus}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" className="h-8 w-8 p-0">
                            <span className="sr-only">Open menu</span>
                            <MoreHorizontal className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem>View Profile</DropdownMenuItem>
                          <DropdownMenuItem>Message</DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
        
        <Card>
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <BarChart className="h-5 w-5" />
                    Performance vs. Average
                </CardTitle>
                <CardDescription>Top 5 couriers by jobs completed.</CardDescription>
            </CardHeader>
            <CardContent>
                <ChartContainer config={chartConfig} className="h-96 w-full">
                  <RechartsBarChart data={chartData} margin={{ top: 20, right: 20, bottom: 5, left: 0 }}>
                      <CartesianGrid vertical={false} />
                      <XAxis dataKey="name" tickLine={false} tickMargin={10} axisLine={false} />
                      <YAxis />
                      <ChartTooltip content={<ChartTooltipContent />} />
                      <ChartLegend content={<ChartLegendContent />} />
                      <Bar dataKey="completed" fill="var(--color-completed)" radius={4} />
                      <Bar dataKey="average" fill="var(--color-average)" radius={4} />
                  </RechartsBarChart>
                </ChartContainer>
            </CardContent>
        </Card>
      </div>
    </div>
  );
}
