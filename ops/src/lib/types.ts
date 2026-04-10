export type Courier = {
  id: string;
  name: string;
  avatarUrl: string;
  courierStatus: 'active' | 'inactive' | 'on-duty' | 'off-duty';
  averageRating: number;
  jobsCompleted: number;
  registrationDate: string;
  acceptanceRate: number;
  historicalAverage: {
    jobs: number;
    rating: number;
  };
};

export type Job = {
  id: string;
  status: 'pending' | 'in-progress' | 'completed' | 'cancelled';
  clientId: string;
  courierId: string | null;
  lastReportedAt: string;
  pickupLocation: string;
  dropoffLocation: string;
};

export type MatchLog = {
  orderId: string;
  courierId: string;
  courierName: string;
  detourCost: number;
  matchScore: number;
  timestamp: string;
  rawResults: {
    courierLocation: [number, number];
    pickupLocation: [number, number];
    dropoffLocation: [number, number];
    originalRouteDistance: number;
    newRouteDistance: number;
    courierReputation: number;
    finalScoreBreakdown: string;
  };
};

export type Admin = {
  id: string;
  name: string;
  email: string;
  role: 'admin' | 'super-admin';
  avatarUrl: string;
};
