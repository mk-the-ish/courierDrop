import type { Metadata } from "next";
import "@/styles/globals.css";
import AdminLayout from "@/components/admin-layout";
import { Toaster } from "@/components/ui/toaster";
import { AdminAuthProvider } from "@/lib/admin-auth";

export const metadata: Metadata = {
  title: "DropCity Admin",
  description: "Admin dashboard for DropCity delivery platform",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="antialiased">
        <AdminAuthProvider>
          <AdminLayout>{children}</AdminLayout>
        </AdminAuthProvider>
        <Toaster />
      </body>
    </html>
  );
}
