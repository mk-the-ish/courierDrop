import type { Metadata } from "next";
import "@/styles/globals.css";
import { AuthProvider } from "@/lib/auth-context";
import AdminLayout from "@/components/admin-layout";
import { Toaster } from "@/components/ui/toaster";

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
        <AuthProvider>
          <AdminLayout>{children}</AdminLayout>
          <Toaster />
        </AuthProvider>
      </body>
    </html>
  );
}
