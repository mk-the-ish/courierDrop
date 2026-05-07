"use client";

import { useEffect, useMemo, useState } from "react";
import { Bell } from "lucide-react";
import { apiClient } from "@/lib/api-client";

type NotificationRow = {
  id: string;
  title: string;
  body: string;
  status: "read" | "unread";
  createdAt?: string;
};

export default function NotificationBell() {
  const [open, setOpen] = useState(false);
  const [rows, setRows] = useState<NotificationRow[]>([]);
  const unreadCount = useMemo(
    () => rows.filter((row) => row.status === "unread").length,
    [rows]
  );

  async function refresh() {
    try {
      const data = (await apiClient.getMyNotifications(undefined, 20, 0)) as {
        notifications?: NotificationRow[];
      };
      setRows(data.notifications || []);
    } catch (error) {
      console.error("Failed to load notifications", error);
    }
  }

  useEffect(() => {
    refresh();
    const timer = window.setInterval(refresh, 15000);
    return () => window.clearInterval(timer);
  }, []);

  const handleMarkRead = async (id: string) => {
    await apiClient.markNotificationRead(id);
    await refresh();
  };

  const handleMarkAllRead = async () => {
    await apiClient.markAllNotificationsRead();
    await refresh();
  };

  return (
    <div className="relative">
      <button
        type="button"
        className="relative rounded-full border border-slate-200 bg-white p-2"
        onClick={() => setOpen((value) => !value)}
      >
        <Bell className="h-5 w-5 text-slate-700" />
        {unreadCount > 0 ? (
          <span className="absolute -right-1 -top-1 min-w-5 rounded-full bg-red-500 px-1 text-center text-xs text-white">
            {unreadCount}
          </span>
        ) : null}
      </button>

      {open ? (
        <div className="absolute right-0 z-20 mt-2 w-96 rounded-lg border border-slate-200 bg-white p-3 shadow-lg">
          <div className="mb-2 flex items-center justify-between">
            <p className="text-sm font-semibold text-slate-900">Notifications</p>
            <button
              type="button"
              className="text-xs text-blue-600"
              onClick={handleMarkAllRead}
            >
              Mark all read
            </button>
          </div>
          <div className="max-h-96 space-y-2 overflow-auto">
            {rows.length === 0 ? (
              <p className="text-sm text-slate-500">No notifications</p>
            ) : (
              rows.map((row) => (
                <button
                  key={row.id}
                  type="button"
                  className="block w-full rounded-md border border-slate-100 p-2 text-left hover:bg-slate-50"
                  onClick={() => handleMarkRead(row.id)}
                >
                  <p className="text-sm font-medium text-slate-900">{row.title}</p>
                  <p className="text-xs text-slate-600">{row.body}</p>
                </button>
              ))
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}
