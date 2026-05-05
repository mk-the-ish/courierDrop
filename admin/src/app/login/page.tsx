"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { AlertCircle, Loader } from "lucide-react";
import { useAdminAuth } from "@/lib/admin-auth";

const baseUrl =
  process.env.NEXT_PUBLIC_API_URL || "https://dropcity-backend.onrender.com";

export default function LoginPage() {
  const router = useRouter();
  const { signIn, signOut } = useAdminAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const token = await signIn(email, password);
      const check = await fetch(`${baseUrl}/health/heartbeats`, {
        cache: "no-store",
      });
      if (!check.ok) {
        await signOut();
        if (check.status === 403) {
          throw new Error("This account is authenticated but not authorized as admin.");
        }
        throw new Error("Admin access check failed.");
      }
      router.replace("/admin");
    } catch (err: any) {
      setError(err?.message || "Login failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900">
      <div className="w-full max-w-md bg-slate-800 rounded-lg shadow-xl p-8 border border-slate-700">
        <h1 className="text-3xl font-bold text-white mb-2">DropCity Admin</h1>
        <p className="text-slate-400 mb-6">Sign in with your Supabase admin account</p>
        {error && (
          <div className="mb-6 p-4 bg-red-500/10 border border-red-500/20 rounded-lg flex items-start gap-3">
            <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
            <p className="text-red-400 text-sm">{error}</p>
          </div>
        )}
        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-4 py-2 rounded-lg bg-slate-700 border border-slate-600 text-white"
            placeholder="admin@example.com"
            required
            disabled={loading}
          />
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full px-4 py-2 rounded-lg bg-slate-700 border border-slate-600 text-white"
            placeholder="Password"
            required
            disabled={loading}
          />
          <button
            type="submit"
            disabled={loading}
            className="w-full py-2 px-4 bg-teal-600 hover:bg-teal-700 text-white font-medium rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {loading && <Loader className="w-4 h-4 animate-spin" />}
            {loading ? "Signing in..." : "Sign In"}
          </button>
        </form>
        <p className="text-slate-400 text-sm mt-4">
          Forgot your password?{" "}
          <a href="/forgot-password" className="text-teal-400 hover:text-teal-300 font-medium">
            Reset it here
          </a>
        </p>
      </div>
    </div>
  );
}
