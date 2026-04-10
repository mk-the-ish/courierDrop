import PageHeader from '@/components/dashboard/page-header';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { WifiOff, MapPin, Dot } from 'lucide-react';

export default function RoutesPage() {
  const apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;
  const mapSrc = `https://www.google.com/maps/embed/v1/view?key=${apiKey}&center=-17.8252,31.0335&zoom=12`;

  return (
    <div className="flex flex-col gap-8">
      <PageHeader title="Route Performance" />
      <Card>
        <CardHeader>
          <CardTitle>Job Density & Connectivity</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-6 lg:grid-cols-3">
          <div className="lg:col-span-2">
            <div className="relative aspect-video w-full overflow-hidden rounded-lg border">
              {apiKey ? (
                <iframe
                  width="100%"
                  height="100%"
                  style={{ border: 0 }}
                  loading="lazy"
                  allowFullScreen
                  src={mapSrc}
                ></iframe>
              ) : (
                <div className="flex h-full w-full items-center justify-center bg-muted">
                  <p className="text-muted-foreground">
                    Google Maps API Key is missing.
                  </p>
                </div>
              )}
            </div>
          </div>
          <div className="flex flex-col gap-4">
            <h3 className="font-semibold">Legend</h3>
            <div className="flex flex-col gap-4 rounded-md border p-4">
              <div className="flex items-start gap-2">
                <MapPin className="h-5 w-5 text-red-500" />
                <div>
                  <p className="font-medium">High Job Density</p>
                  <p className="text-sm text-muted-foreground">
                    Areas with the highest concentration of pickups & dropoffs.
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-2">
                <WifiOff className="h-5 w-5 text-blue-500" />
                <div>
                  <p className="font-medium">Low-Connectivity Zone</p>
                  <p className="text-sm text-muted-foreground">
                    Aggregated data shows poor network reception here.
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-2">
                <Dot className="h-5 w-5 text-green-500" />
                <div>
                  <p className="font-medium">Active Route</p>
                  <p className="text-sm text-muted-foreground">
                    An active courier path is currently being tracked.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
