"use client";

import React, { createContext, useContext, useEffect, useMemo, useState } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase-browser";

type AdminAuthContextType = {
  user: User | null;
  session: Session | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<string>;
  signOut: () => Promise<void>;
  requestPasswordReset: (email: string) => Promise<void>;
  updatePassword: (password: string) => Promise<void>;
  getAccessToken: () => string;
};

const AdminAuthContext = createContext<AdminAuthContextType | undefined>(undefined);

const TOKEN_KEY = "admin_token";

function persistToken(token: string | null) {
  if (typeof window === "undefined") return;
  if (!token) {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem("adminToken");
    return;
  }
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem("adminToken", token);
}

export function AdminAuthProvider({ children }: { children: React.ReactNode }) {
  const [loading, setLoading] = useState(true);
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    let mounted = true;
    if (!supabase) {
      setLoading(false);
      return () => {
        mounted = false;
      };
    }

    supabase.auth
      .getSession()
      .then(({ data }) => {
        if (!mounted) return;
        const nextSession = data.session ?? null;
        setSession(nextSession);
        setUser(nextSession?.user ?? null);
        persistToken(nextSession?.access_token ?? null);
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setUser(nextSession?.user ?? null);
      persistToken(nextSession?.access_token ?? null);
      setLoading(false);
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);

  const value = useMemo<AdminAuthContextType>(
    () => ({
      user,
      session,
      loading,
      async signIn(email: string, password: string) {
        if (!supabase) throw new Error("Supabase env is not configured.");
        const { data, error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
        return data.session?.access_token || "";
      },
      async signOut() {
        if (!supabase) throw new Error("Supabase env is not configured.");
        const { error } = await supabase.auth.signOut();
        persistToken(null);
        if (error) throw error;
      },
      async requestPasswordReset(email: string) {
        if (!supabase) throw new Error("Supabase env is not configured.");
        const redirectTo =
          typeof window !== "undefined"
            ? `${window.location.origin}/reset-password`
            : undefined;
        const { error } = await supabase.auth.resetPasswordForEmail(email, {
          redirectTo,
        });
        if (error) throw error;
      },
      async updatePassword(password: string) {
        if (!supabase) throw new Error("Supabase env is not configured.");
        const { error } = await supabase.auth.updateUser({ password });
        if (error) throw error;
      },
      getAccessToken() {
        return session?.access_token || "";
      },
    }),
    [loading, session, user],
  );

  return <AdminAuthContext.Provider value={value}>{children}</AdminAuthContext.Provider>;
}

export function useAdminAuth() {
  const context = useContext(AdminAuthContext);
  if (!context) {
    throw new Error("useAdminAuth must be used within AdminAuthProvider");
  }
  return context;
}
