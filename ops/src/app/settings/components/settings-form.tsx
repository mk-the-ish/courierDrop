"use client";

import { useState } from 'react';
import type { Courier, Admin } from '@/lib/types';
import PageHeader from '@/components/dashboard/page-header';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { Slider } from '@/components/ui/slider';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { PlusCircle, Trash2 } from 'lucide-react';
import { Separator } from '@/components/ui/separator';

type SettingsFormProps = {
  couriers: Courier[];
  admins: Admin[];
};

export default function SettingsForm({
  couriers: initialCouriers,
  admins: initialAdmins,
}: SettingsFormProps) {
  const [courierStatus, setCourierStatus] = useState<Record<string, boolean>>(
    initialCouriers.reduce((acc, c) => {
      acc[c.id] = c.courierStatus === 'active' || c.courierStatus === 'on-duty' || c.courierStatus === 'off-duty';
      return acc;
    }, {} as Record<string, boolean>)
  );
  const [alpha, setAlpha] = useState(0.7);
  const [beta, setBeta] = useState(0.3);

  const handleCourierStatusChange = (courierId: string, checked: boolean) => {
    setCourierStatus((prev) => ({ ...prev, [courierId]: checked }));
  };

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="System Settings"
        actions={<Button>Save Changes</Button>}
      />
      <div className="grid gap-8">
        <Card>
          <CardHeader>
            <CardTitle>Rating Weights</CardTitle>
            <CardDescription>
              Adjust the algorithmic weights for courier ratings.
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-6">
            <div className="grid gap-2">
              <Label htmlFor="alpha" className="flex justify-between">
                <span>Alpha (α) - Detour Cost Weight</span>
                <span className="font-bold">{alpha.toFixed(2)}</span>
              </Label>
              <Slider
                id="alpha"
                min={0}
                max={1}
                step={0.05}
                value={[alpha]}
                onValueChange={(value) => setAlpha(value[0])}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="beta" className="flex justify-between">
                <span>Beta (β) - Reputation Weight</span>
                <span className="font-bold">{beta.toFixed(2)}</span>
              </Label>
              <Slider
                id="beta"
                min={0}
                max={1}
                step={0.05}
                value={[beta]}
                onValueChange={(value) => setBeta(value[0])}
              />
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Courier Management</CardTitle>
            <CardDescription>
              Activate or deactivate couriers on the platform.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {initialCouriers.map((courier, index) => (
              <div key={courier.id}>
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <Avatar className="h-9 w-9">
                      <AvatarImage src={courier.avatarUrl} />
                      <AvatarFallback>{courier.name.charAt(0)}</AvatarFallback>
                    </Avatar>
                    <div>
                      <p className="font-medium">{courier.name}</p>
                      <p className="text-sm text-muted-foreground">{courier.id}</p>
                    </div>
                  </div>
                  <Switch
                    checked={courierStatus[courier.id]}
                    onCheckedChange={(checked) =>
                      handleCourierStatusChange(courier.id, checked)
                    }
                  />
                </div>
                {index < initialCouriers.length - 1 && <Separator className="mt-4" />}
              </div>
            ))}
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Administrator Accounts</CardTitle>
            <CardDescription>
              Manage users with dashboard access.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="mb-4 flex justify-end">
                <Button variant="outline">
                    <PlusCircle className="mr-2 h-4 w-4" />
                    Add Administrator
                </Button>
            </div>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>User</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Role</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {initialAdmins.map((admin) => (
                  <TableRow key={admin.id}>
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <Avatar>
                          <AvatarImage src={admin.avatarUrl} />
                          <AvatarFallback>{admin.name.charAt(0)}</AvatarFallback>
                        </Avatar>
                        <span className="font-medium">{admin.name}</span>
                      </div>
                    </TableCell>
                    <TableCell>{admin.email}</TableCell>
                    <TableCell className="capitalize">{admin.role}</TableCell>
                    <TableCell>
                      <Button variant="ghost" size="icon" className="text-muted-foreground">
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </TableCell>
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
