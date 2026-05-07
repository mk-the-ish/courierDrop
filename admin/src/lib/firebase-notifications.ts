export interface FirebaseNotificationItem {
  id: string;
  type: string;
  title: string;
  body: string;
  entityType?: string | null;
  entityId?: string | null;
  payload?: Record<string, unknown>;
  status: "unread" | "read";
  createdAt?: string;
  readAt?: string | null;
  source?: string;
}

export function notificationsCollectionPath(uid: string) {
  return `users/${uid}/notifications`;
}
