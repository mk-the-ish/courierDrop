-- Create base_fares table for price recommendation
CREATE TABLE IF NOT EXISTS public.base_fares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  corridor_name TEXT NOT NULL UNIQUE,
  start_location TEXT NOT NULL,
  end_location TEXT NOT NULL,
  distance_km NUMERIC NOT NULL,
  passenger_fare_usd NUMERIC NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Common Harare corridors with sample data
INSERT INTO public.base_fares (corridor_name, start_location, end_location, distance_km, passenger_fare_usd)
VALUES
  ('CBD-UZ', 'Harare CBD', 'University of Zimbabwe', 8.5, 1.50),
  ('CBD-Chitungwiza', 'Harare CBD', 'Chitungwiza', 25.0, 2.50),
  ('CBD-Westgate', 'Harare CBD', 'Westgate', 6.0, 1.20),
  ('CBD-Mount Pleasant', 'Harare CBD', 'Mount Pleasant', 12.0, 1.80),
  ('CBD-Avondale', 'Harare CBD', 'Avondale', 10.0, 1.60),
  ('CBD-Belgravia', 'Harare CBD', 'Belgravia', 8.0, 1.40),
  ('CBD-Waterfalls', 'Harare CBD', 'Waterfalls', 15.0, 2.00),
  ('CBD-Borrowdale', 'Harare CBD', 'Borrowdale', 18.0, 2.30),
  ('UZ-Mount Pleasant', 'University of Zimbabwe', 'Mount Pleasant', 10.0, 1.60),
  ('Chitungwiza-Harare', 'Chitungwiza', 'Harare CBD', 25.0, 2.50)
ON CONFLICT (corridor_name) DO NOTHING;

-- Create index for corridor lookups
CREATE INDEX IF NOT EXISTS base_fares_corridor_name_idx ON public.base_fares(corridor_name);
CREATE INDEX IF NOT EXISTS base_fares_distance_idx ON public.base_fares(distance_km);

-- Size multipliers table for price calculation
CREATE TABLE IF NOT EXISTS public.size_multipliers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  size_code TEXT NOT NULL UNIQUE,
  size_label TEXT NOT NULL,
  multiplier NUMERIC NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Small/Medium/Large size multipliers
INSERT INTO public.size_multipliers (size_code, size_label, multiplier)
VALUES
  ('S', 'Small (Backpack)', 0.5),
  ('M', 'Medium (Seat)', 1.0),
  ('L', 'Large (Dedicated Seat)', 2.0)
ON CONFLICT (size_code) DO NOTHING;

CREATE INDEX IF NOT EXISTS size_multipliers_code_idx ON public.size_multipliers(size_code);
