"use client";

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  FileText,
  LayoutDashboard,
  Map,
  Package,
  PanelLeft,
  Settings,
  Users,
} from 'lucide-react';
import {
  SidebarProvider,
  Sidebar,
  SidebarHeader,
  SidebarContent,
  SidebarMenu,
  SidebarMenuItem,
  SidebarMenuButton,
  SidebarInset,
  SidebarFooter,
} from '@/components/ui/sidebar';
import { Button } from '@/components/ui/button';
import { Sheet, SheetContent, SheetTrigger } from '@/components/ui/sheet';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

const navItems = [
  { href: '/', label: 'Overview', icon: LayoutDashboard },
  { href: '/routes', label: 'Routes', icon: Map },
  { href: '/couriers', label: 'Couriers', icon: Users },
  { href: '/matching', label: 'Match Analysis', icon: FileText },
  { href: '/settings', label: 'Settings', icon: Settings },
];

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();

  const SidebarNav = ({ className }: { className?: string }) => (
    <nav className={className}>
      <SidebarMenu>
        {navItems.map((item) => (
          <SidebarMenuItem key={item.href}>
            <Link href={item.href} passHref>
              <SidebarMenuButton
                as="a"
                isActive={pathname === item.href}
                tooltip={item.label}
              >
                <item.icon />
                <span>{item.label}</span>
              </SidebarMenuButton>
            </Link>
          </SidebarMenuItem>
        ))}
      </SidebarMenu>
    </nav>
  );

  return (
    <SidebarProvider>
      <Sidebar
        collapsible="icon"
        variant="sidebar"
        className="dark:bg-background dark:border-r"
      >
        <SidebarHeader className="h-16 border-b dark:border-border">
          <Link href="/" className="flex items-center gap-2 font-bold">
            <Package className="h-6 w-6 text-primary" />
            <span className="text-lg text-sidebar-foreground">DropCity</span>
          </Link>
        </SidebarHeader>
        <SidebarContent>
          <SidebarNav />
        </SidebarContent>
        <SidebarFooter>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="ghost"
                className="w-full justify-start gap-2 px-2"
              >
                <Avatar className="h-8 w-8">
                  <AvatarImage src="https://i.pravatar.cc/150?u=ADMIN-001" />
                  <AvatarFallback>JD</AvatarFallback>
                </Avatar>
                <div className="text-left">
                  <p className="text-sm font-medium text-sidebar-foreground">
                    Jane Doe
                  </p>
                  <p className="text-xs text-muted-foreground">
                    Super Admin
                  </p>
                </div>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent side="right" align="start">
              <DropdownMenuLabel>My Account</DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem>Profile</DropdownMenuItem>
              <DropdownMenuItem>Billing</DropdownMenuItem>
              <DropdownMenuItem>Settings</DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem>Log out</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </SidebarFooter>
      </Sidebar>
      <SidebarInset>
        <header className="sticky top-0 z-30 flex h-14 items-center gap-4 border-b bg-background px-4 sm:static sm:h-auto sm:border-0 sm:bg-transparent sm:px-6 md:hidden">
          <Sheet>
            <SheetTrigger asChild>
              <Button size="icon" variant="outline" className="sm:hidden">
                <PanelLeft className="h-5 w-5" />
                <span className="sr-only">Toggle Menu</span>
              </Button>
            </SheetTrigger>
            <SheetContent side="left" className="sm:max-w-xs bg-sidebar">
              <SidebarNav className="flex flex-col" />
            </SheetContent>
          </Sheet>
          <div className="flex items-center gap-2 font-bold text-foreground">
            <Package className="h-6 w-6 text-primary" />
            <span className="text-lg">DropCity</span>
          </div>
        </header>
        <main className="flex-1 p-4 sm:px-6 sm:py-0">{children}</main>
      </SidebarInset>
    </SidebarProvider>
  );
}
