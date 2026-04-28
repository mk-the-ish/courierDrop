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

    try {
      const response = await fetch(url, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
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
}

export const apiClient = new ApiClient();
