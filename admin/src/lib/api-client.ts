/**
 * API Client for DropCity Backend
 * Communicates with https://dropcity-backend.onrender.com
 */

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://dropcity-backend.onrender.com';

interface ApiResponse<T> {
  requestId: string;
  data?: T;
  [key: string]: any;
}

class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string = API_URL) {
    this.baseUrl = baseUrl;
  }

  private async request<T>(endpoint: string, options?: RequestInit): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    
    // Get token from localStorage
    const token = typeof window !== 'undefined' 
      ? localStorage.getItem('admin_token') || localStorage.getItem('adminToken')
      : null;

    try {
      const response = await fetch(url, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          ...(token && { 'Authorization': `Bearer ${token}` }),  // ← ADD THIS
          ...options?.headers,
        },
      });

      if (!response.ok) {
        throw new Error(`API Error: ${response.status} ${response.statusText}`);
      }

      const data: ApiResponse<T> = await response.json();
      return (data.data || data) as T;
    } catch (error) {
      console.error(`API Request failed: ${endpoint}`, error);
      throw error;
    }
  }

  // Health & System
  async getHealth() {
    return this.request('/');
  }

  async getHeartbeats() {
    return this.request('/health/heartbeats');
  }

  async getHealthStatus() {
    return this.request('/health/status');
  }

  // Admin routes
  async getJobs() {
    return this.request('/health/jobs');
  }

  async getCouriers() {
    return this.request('/admin/couriers');
  }

  async getAlerts() {
    return this.request('/admin/alerts/rules');
  }

  async getMyNotifications(status?: "read" | "unread", limit = 20, offset = 0) {
    const params = new URLSearchParams({
      limit: String(limit),
      offset: String(offset),
    });
    if (status) {
      params.set("status", status);
    }
    return this.request(`/notifications/me?${params.toString()}`);
  }

  async markNotificationRead(notificationId: string) {
    return this.request(`/notifications/${notificationId}/read`, {
      method: "POST",
    });
  }

  async markAllNotificationsRead() {
    return this.request(`/notifications/read-all`, {
      method: "POST",
    });
  }
}

export const apiClient = new ApiClient();
