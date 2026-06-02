require("dotenv").config({ path: require("path").resolve(__dirname, "..", ".env") });

const { createClient } = require("@supabase/supabase-js");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in backend/.env");
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false }
});

const now = new Date();
const isoMinutesFromNow = (minutes) => new Date(now.getTime() + minutes * 60 * 1000).toISOString();
const isoMinutesAgo = (minutes) => new Date(now.getTime() - minutes * 60 * 1000).toISOString();
const sqlPoint = (lng, lat) => `SRID=4326;POINT(${lng} ${lat})`;
const sqlLine = (coords) => `SRID=4326;LINESTRING(${coords.map(([lng, lat]) => `${lng} ${lat}`).join(",")})`;

async function upsert(table, rows, onConflict = "id") {
  if (!rows.length) return;
  const { error } = await supabase.from(table).upsert(rows, { onConflict });
  if (error) {
    throw new Error(`${table}: ${error.message}`);
  }
}

async function seed() {
  const ids = {
    admin: "admin-harare-001",
    courier1: "courier-harare-001",
    courier2: "courier-harare-002",
    client1: "client-harare-001",
    client2: "client-harare-002",

    routeTemplateOutbound: "11111111-1111-4111-8111-111111111111",
    routeTemplateReturn: "11111111-1111-4111-8111-111111111112",
    corridorActive: "21111111-1111-4111-8111-111111111111",
    corridorPlanned: "21111111-1111-4111-8111-111111111112",
    routeActive: "31111111-1111-4111-8111-111111111111",
    routePlanned: "31111111-1111-4111-8111-111111111112",

    parcelRequested: "41111111-1111-4111-8111-111111111111",
    parcelInTransit: "41111111-1111-4111-8111-111111111112",
    parcelDelivered: "41111111-1111-4111-8111-111111111113",

    tracking1: "51111111-1111-4111-8111-111111111111",
    tracking2: "51111111-1111-4111-8111-111111111112",
    tracking3: "51111111-1111-4111-8111-111111111113",
    deviation1: "61111111-1111-4111-8111-111111111111",
    disputeAudit1: "62111111-1111-4111-8111-111111111111",
    alertRule1: "63111111-1111-4111-8111-111111111111",
    alertHistory1: "64111111-1111-4111-8111-111111111111",
    notification1: "71111111-1111-4111-8111-111111111111",
    notification2: "71111111-1111-4111-8111-111111111112",
    heartbeats: ["validate_tracking", "cleanup_tracking_data", "process_notification_outbox", "aggregate_courier_scores", "heuristic_tracking_sweep"],
    error1: "81111111-1111-4111-8111-111111111111",
    error2: "81111111-1111-4111-8111-111111111112",
    etaLog1: "91111111-1111-4111-8111-111111111111",
    priceLog1: "92111111-1111-4111-8111-111111111111",
    pricingHistory1: "93111111-1111-4111-8111-111111111111",
    adherence1: "94111111-1111-4111-8111-111111111111",
    scoreSnapshot1: "95111111-1111-4111-8111-111111111111",
    loc1: "96111111-1111-4111-8111-111111111111",
    loc2: "96111111-1111-4111-8111-111111111112",
    loc3: "96111111-1111-4111-8111-111111111113",
    connAudit1: "97111111-1111-4111-8111-111111111111",
    connAudit2: "97111111-1111-4111-8111-111111111112",
    connAudit3: "97111111-1111-4111-8111-111111111113",
    connectivityMap1: "98111111-1111-4111-8111-111111111111",
    connectivityMap2: "98111111-1111-4111-8111-111111111112",
    zone1: "99111111-1111-4111-8111-111111111111",
    zone2: "99111111-1111-4111-8111-111111111112"
  };

  console.log("Seeding Harare demo data...");

  await upsert("users", [
    {
      id: ids.admin,
      email: "ops.admin@dropcity.co.zw",
      role: "admin",
      display_name: "Tariro Moyo",
      phone_number: "+263777000001",
      is_active: true,
      is_verified: true,
      verification_status: "APPROVED",
      auth_method: "supabase"
    },
    {
      id: ids.courier1,
      email: "mukanya.courier@dropcity.co.zw",
      role: "courier",
      display_name: "Tawanda Mukanya",
      phone_number: "+263777000101",
      is_active: true,
      is_verified: true,
      verification_status: "APPROVED",
      profile_complete: true,
      courier_score: 4.68,
      courier_score_updated_at: now.toISOString()
    },
    {
      id: ids.courier2,
      email: "nyasha.courier@dropcity.co.zw",
      role: "courier",
      display_name: "Nyasha Chisoro",
      phone_number: "+263777000102",
      is_active: true,
      is_verified: true,
      verification_status: "PENDING",
      profile_complete: true,
      courier_score: 4.21,
      courier_score_updated_at: now.toISOString()
    },
    {
      id: ids.client1,
      email: "rudo.sender@dropcity.co.zw",
      role: "client",
      display_name: "Rudo Zindi",
      phone_number: "+263777000201",
      is_active: true,
      is_verified: false,
      verification_status: "PENDING",
      profile_complete: true
    },
    {
      id: ids.client2,
      email: "takura.receiver@dropcity.co.zw",
      role: "client",
      display_name: "Takura Mupfuti",
      phone_number: "+263777000202",
      is_active: true,
      is_verified: false,
      verification_status: "PENDING",
      profile_complete: true
    }
  ]);

  await upsert("client_profiles", [
    {
      id: ids.client1,
      full_name: "Rudo Zindi",
      username: "rudoz",
      id_number: "63-123456Z12",
      id_image_url: "https://example.com/dropcity/demo/rudo-id.jpg",
      phone_number: "+263777000201",
      profile_complete: true
    },
    {
      id: ids.client2,
      full_name: "Takura Mupfuti",
      username: "takura_m",
      id_number: "63-654321X77",
      id_image_url: "https://example.com/dropcity/demo/takura-id.jpg",
      phone_number: "+263777000202",
      profile_complete: true
    }
  ]);

  await upsert("courier_profiles", [
    {
      id: ids.courier1,
      full_name: "Tawanda Mukanya",
      id_number: "63-998877A45",
      id_image_url: "https://example.com/dropcity/demo/tawanda-id.jpg",
      license_number: "ZIM-DRV-120993",
      license_image_url: "https://example.com/dropcity/demo/tawanda-license.jpg",
      vehicle_registration: "AEK 7421",
      vehicle_registration_images: [
        "https://example.com/dropcity/demo/tawanda-reg-front.jpg",
        "https://example.com/dropcity/demo/tawanda-reg-back.jpg"
      ],
      vehicle_type: "Sedan",
      vehicle_make: "Toyota",
      vehicle_model: "Aqua",
      vehicle_year: 2018,
      vehicle_color: "Pearl White",
      vehicle_capacity_kg: 180,
      profile_complete: true,
      verified_at: now.toISOString(),
      verification_notes: "Harare CBD ready"
    },
    {
      id: ids.courier2,
      full_name: "Nyasha Chisoro",
      id_number: "63-112233B11",
      id_image_url: "https://example.com/dropcity/demo/nyasha-id.jpg",
      license_number: "ZIM-DRV-998811",
      license_image_url: "https://example.com/dropcity/demo/nyasha-license.jpg",
      vehicle_registration: "AFJ 5108",
      vehicle_registration_images: [
        "https://example.com/dropcity/demo/nyasha-reg-front.jpg"
      ],
      vehicle_type: "Hatchback",
      vehicle_make: "Honda",
      vehicle_model: "Fit",
      vehicle_year: 2017,
      vehicle_color: "Blue",
      vehicle_capacity_kg: 140,
      profile_complete: true
    }
  ]);

  await upsert("vehicles", [
    {
      courier_id: ids.courier1,
      vehicle_type: "Sedan",
      make: "Toyota",
      model: "Aqua",
      year: 2018,
      color: "Pearl White",
      registration_number: "AEK 7421",
      license_plate: "AEK 7421",
      max_capacity_kg: 180,
      current_utilization_kg: 24,
      is_active: true,
      verification_status: "verified",
      verification_photos: {
        front: "https://example.com/dropcity/demo/tawanda-car-front.jpg",
        rear: "https://example.com/dropcity/demo/tawanda-car-rear.jpg"
      },
      verified_at: now.toISOString()
    },
    {
      courier_id: ids.courier2,
      vehicle_type: "Hatchback",
      make: "Honda",
      model: "Fit",
      year: 2017,
      color: "Blue",
      registration_number: "AFJ 5108",
      license_plate: "AFJ 5108",
      max_capacity_kg: 140,
      current_utilization_kg: 10,
      is_active: true,
      verification_status: "unverified",
      verification_photos: {
        front: "https://example.com/dropcity/demo/nyasha-car-front.jpg"
      }
    }
  ], "courier_id");

  await upsert("route_templates", [
    {
      id: ids.routeTemplateOutbound,
      courier_id: ids.courier1,
      start_location: "Harare CBD",
      end_location: "Borrowdale",
      start_point: sqlPoint(31.0335, -17.8252),
      end_point: sqlPoint(31.1030, -17.7830),
      route_line: sqlLine([
        [31.0335, -17.8252],
        [31.0450, -17.8185],
        [31.0680, -17.8040],
        [31.1030, -17.7830]
      ]),
      allow_multiple_parcels: true,
      declared_eta_minutes: 32,
      notes: "Morning CBD to Borrowdale commuter corridor"
    },
    {
      id: ids.routeTemplateReturn,
      courier_id: ids.courier1,
      start_location: "Borrowdale",
      end_location: "Harare CBD",
      start_point: sqlPoint(31.1030, -17.7830),
      end_point: sqlPoint(31.0335, -17.8252),
      route_line: sqlLine([
        [31.1030, -17.7830],
        [31.0870, -17.7950],
        [31.0580, -17.8125],
        [31.0335, -17.8252]
      ]),
      allow_multiple_parcels: true,
      declared_eta_minutes: 29,
      notes: "Evening return corridor"
    }
  ]);

  await upsert("corridors", [
    {
      id: ids.corridorActive,
      created_by: ids.courier1,
      start_location: "Harare CBD",
      end_location: "Borrowdale",
      start_point: sqlPoint(31.0335, -17.8252),
      end_point: sqlPoint(31.1030, -17.7830),
      corridor_line: sqlLine([
        [31.0335, -17.8252],
        [31.0430, -17.8200],
        [31.0600, -17.8110],
        [31.0830, -17.7965],
        [31.1030, -17.7830]
      ]),
      window_start: "08:00",
      window_end: "10:30",
      allow_multiple_parcels: true,
      notes: "Active morning corridor for CBD pickups",
      request_id: "demo-corridor-active"
    },
    {
      id: ids.corridorPlanned,
      created_by: ids.courier2,
      start_location: "Borrowdale",
      end_location: "Harare CBD",
      start_point: sqlPoint(31.1030, -17.7830),
      end_point: sqlPoint(31.0335, -17.8252),
      corridor_line: sqlLine([
        [31.1030, -17.7830],
        [31.0900, -17.7925],
        [31.0700, -17.8035],
        [31.0490, -17.8150],
        [31.0335, -17.8252]
      ]),
      window_start: "12:00",
      window_end: "14:30",
      allow_multiple_parcels: true,
      notes: "Return corridor awaiting activation",
      request_id: "demo-corridor-planned"
    }
  ]);

  await upsert("routes", [
    {
      id: ids.routeActive,
      courier_id: ids.courier1,
      corridor_id: ids.corridorActive,
      start_point: sqlPoint(31.0335, -17.8252),
      end_point: sqlPoint(31.1030, -17.7830),
      planned_start_at: isoMinutesAgo(45),
      declared_eta_minutes: 32,
      expected_duration_minutes: 34,
      status: "ACTIVE",
      activated_at: isoMinutesAgo(40),
      metadata: {
        template: "Harare CBD -> Borrowdale"
      }
    },
    {
      id: ids.routePlanned,
      courier_id: ids.courier2,
      corridor_id: ids.corridorPlanned,
      start_point: sqlPoint(31.1030, -17.7830),
      end_point: sqlPoint(31.0335, -17.8252),
      planned_start_at: isoMinutesFromNow(35),
      declared_eta_minutes: 29,
      expected_duration_minutes: 31,
      status: "PLANNED",
      metadata: {
        template: "Borrowdale -> Harare CBD"
      }
    }
  ]);

  for (const row of [
    { id: ids.courier1, current_route_id: ids.corridorActive },
    { id: ids.courier2, current_route_id: ids.corridorPlanned }
  ]) {
    const { error } = await supabase
      .from("users")
      .update({ current_route_id: row.current_route_id })
      .eq("id", row.id);
    if (error) {
      throw new Error(`users current_route_id update: ${error.message}`);
    }
  }

  await upsert("parcels", [
    {
      id: ids.parcelRequested,
      created_by: ids.client1,
      origin: "Harare CBD",
      destination: "Borrowdale Brooke",
      origin_point: sqlPoint(31.0335, -17.8252),
      destination_point: sqlPoint(31.1075, -17.7720),
      pickup_point: sqlPoint(31.0335, -17.8252),
      dropoff_point: sqlPoint(31.1075, -17.7720),
      size: "Medium",
      size_code: "M",
      priority: "NORMAL",
      fragile: false,
      notes: "Invoice documents and a small box of samples",
      status: "REQUESTED",
      privacy_mode: true,
      request_id: "demo-parcel-requested",
      assigned_courier_id: null,
      dual_tracking: true,
      recipient_id: ids.client2,
      weight_kg: 3.2,
      recommended_price: 5.5,
      user_price: 6.0,
      final_price: 5.5,
      client_eta_minutes: 32,
      rating_submitted: false
    },
    {
      id: ids.parcelInTransit,
      created_by: ids.client1,
      origin: "Avondale",
      destination: "Mbare Musika",
      origin_point: sqlPoint(31.0210, -17.7825),
      destination_point: sqlPoint(31.0531, -17.8904),
      pickup_point: sqlPoint(31.0210, -17.7825),
      dropoff_point: sqlPoint(31.0531, -17.8904),
      size: "Large",
      size_code: "L",
      priority: "URGENT",
      fragile: true,
      notes: "Retail stock transfer",
      status: "IN_TRANSIT",
      privacy_mode: true,
      request_id: "demo-parcel-in-transit",
      assigned_courier_id: ids.courier1,
      assigned_at: isoMinutesAgo(70),
      dual_tracking: true,
      recipient_id: ids.client2,
      weight_kg: 11.6,
      tracking_progress_percent: 58,
      tracking_integrity_status: "ON_CORRIDOR",
      tracking_last_update: isoMinutesAgo(4),
      recommended_price: 8.0,
      user_price: 9.0,
      final_price: 8.5,
      client_eta_minutes: 24,
      rating_submitted: false
    },
    {
      id: ids.parcelDelivered,
      created_by: ids.client2,
      origin: "Highlands",
      destination: "Westgate",
      origin_point: sqlPoint(31.1050, -17.8070),
      destination_point: sqlPoint(31.0285, -17.7980),
      pickup_point: sqlPoint(31.1050, -17.8070),
      dropoff_point: sqlPoint(31.0285, -17.7980),
      size: "Small",
      size_code: "S",
      priority: "LOW",
      fragile: false,
      notes: "Gift bag",
      status: "DELIVERED",
      privacy_mode: true,
      request_id: "demo-parcel-delivered",
      assigned_courier_id: ids.courier2,
      assigned_at: isoMinutesAgo(240),
      pickup_verified_at: isoMinutesAgo(220),
      dropoff_verified_at: isoMinutesAgo(185),
      pickup_photo_url: "https://example.com/dropcity/demo/pickup-delivered.jpg",
      dropoff_photo_url: "https://example.com/dropcity/demo/dropoff-delivered.jpg",
      pickup_verified_by: ids.courier2,
      dropoff_verified_by: ids.client1,
      rating_submitted: true,
      rating_value: 5,
      rating_feedback: "Fast and courteous",
      rated_at: isoMinutesAgo(170),
      dual_tracking: false,
      recipient_id: null,
      weight_kg: 1.0,
      tracking_progress_percent: 100,
      tracking_integrity_status: "NOMINAL",
      tracking_last_update: isoMinutesAgo(180),
      route_adherence_percent: 96,
      punctuality_minutes_delta: -6,
      recommended_price: 4.2,
      user_price: 4.5,
      final_price: 4.2,
      client_eta_minutes: 18,
      rating_submitted: true
    }
  ]);

  await upsert("parcel_assignment_queue", [
    {
      id: "a1111111-1111-4111-8111-111111111111",
      parcel_id: ids.parcelRequested,
      corridor_id: ids.corridorActive,
      rank: 1,
      status: "PENDING"
    }
  ]);

  await upsert("courier_locations", [
    {
      id: ids.loc1,
      courier_id: ids.courier1,
      location_point: sqlPoint(31.0345, -17.8245),
      accuracy_m: 11,
      speed_kmh: 18,
      heading: 92,
      altitude_m: 1472,
      recorded_at: isoMinutesAgo(8)
    },
    {
      id: ids.loc2,
      courier_id: ids.courier1,
      location_point: sqlPoint(31.0470, -17.8188),
      accuracy_m: 10,
      speed_kmh: 24,
      heading: 88,
      altitude_m: 1468,
      recorded_at: isoMinutesAgo(5)
    },
    {
      id: ids.loc3,
      courier_id: ids.courier1,
      location_point: sqlPoint(31.0605, -17.8108),
      accuracy_m: 9,
      speed_kmh: 28,
      heading: 84,
      altitude_m: 1465,
      recorded_at: isoMinutesAgo(2)
    }
  ]);

  await upsert("courier_tracking_logs", [
    {
      id: ids.tracking1,
      parcel_id: ids.parcelInTransit,
      courier_id: ids.courier1,
      raw_location: sqlPoint(31.0345, -17.8245),
      corridor_id: ids.corridorActive,
      is_on_corridor: true,
      progress_index: 0.23,
      previous_distance_m: 3100,
      current_distance_m: 2850,
      movement_direction: "EAST",
      via_batch_sync: false,
      device_info: { model: "Samsung A04", os: "Android 14" },
      network_info: { network_provider: "Econet", device_model: "Samsung A04" },
      vector_progress_delta: 0.05,
      heuristic_flags: { off_corridor: false },
      speed_kmh: 18.4,
      waypoint_tag: "PICKUP",
      created_at: isoMinutesAgo(7)
    },
    {
      id: ids.tracking2,
      parcel_id: ids.parcelInTransit,
      courier_id: ids.courier1,
      raw_location: sqlPoint(31.0470, -17.8188),
      corridor_id: ids.corridorActive,
      is_on_corridor: true,
      progress_index: 0.47,
      previous_distance_m: 2850,
      current_distance_m: 1900,
      movement_direction: "EAST",
      via_batch_sync: true,
      device_info: { model: "Samsung A04", os: "Android 14" },
      network_info: { network_provider: "Econet", device_model: "Samsung A04" },
      vector_progress_delta: 0.14,
      heuristic_flags: { off_corridor: false },
      speed_kmh: 24.8,
      waypoint_tag: "MIDPOINT",
      created_at: isoMinutesAgo(4)
    },
    {
      id: ids.tracking3,
      parcel_id: ids.parcelInTransit,
      courier_id: ids.courier1,
      raw_location: sqlPoint(31.0605, -17.8108),
      corridor_id: ids.corridorActive,
      is_on_corridor: true,
      progress_index: 0.58,
      previous_distance_m: 1900,
      current_distance_m: 1400,
      movement_direction: "EAST",
      via_batch_sync: true,
      device_info: { model: "Samsung A04", os: "Android 14" },
      network_info: { network_provider: "Econet", device_model: "Samsung A04" },
      vector_progress_delta: 0.09,
      heuristic_flags: { off_corridor: false },
      speed_kmh: 22.1,
      waypoint_tag: "DROPOFF",
      created_at: isoMinutesAgo(1)
    }
  ]);

  await upsert("route_deviation_events", [
    {
      id: ids.deviation1,
      parcel_id: ids.parcelInTransit,
      courier_id: ids.courier1,
      deviation_type: "OFF_CORRIDOR_PROLONGED",
      duration_seconds: 300,
      last_on_corridor_at: isoMinutesAgo(12),
      last_progress_increase_at: isoMinutesAgo(4),
      resolution_status: "OPEN",
      resolution_notes: "Demo evidence for admin workflow",
      resolved_at: null,
      resolved_by: null
    }
  ]);

  await upsert("dispute_resolution_audit", [
    {
      id: ids.disputeAudit1,
      dispute_id: ids.deviation1,
      parcel_id: ids.parcelInTransit,
      courier_id: ids.courier1,
      admin_id: ids.admin,
      decision: "ESCALATE",
      notes: "Need route deviation review for Harare CBD corridor",
      partial_amount: null,
      metadata: { source: "demo_seed" }
    }
  ]);

  await upsert("route_adherence_reports", [
    {
      id: ids.adherence1,
      courier_id: ids.courier1,
      parcel_id: ids.parcelInTransit,
      adherence_score: 91,
      off_corridor_ratio: 0.09,
      stationary_minutes: 6,
      max_speed_kmh: 29.2,
      anomalies: ["OFF_CORRIDOR_PROLONGED"],
      pickup_visited: true,
      dropoff_visited: false,
      generated_at: now.toISOString()
    }
  ]);

  try {
    await upsert("courier_score_snapshots", [
      {
        id: ids.scoreSnapshot1,
        courier_id: ids.courier1,
        score: 4.68,
        components: {
          source: "demo_seed",
          route_adherence: 91,
          punctuality: 4.7,
          client_rating: 5
        }
      }
    ]);
  } catch (error) {
    console.warn(`Skipping courier_score_snapshots seed: ${error.message}`);
  }

  await upsert("eta_calculations_log", [
    {
      id: ids.etaLog1,
      parcel_id: ids.parcelInTransit,
      courier_id: ids.courier1,
      corridor_id: ids.corridorActive,
      eta_minutes: 24,
      confidence: "MEDIUM",
      confidence_score: 0.71,
      distance_meters: 5200,
      breakdown: [
        { source: "declared", minutes: 29 },
        { source: "distance_speed", minutes: 22 },
        { source: "historical_corridor", minutes: 24 }
      ]
    }
  ]);

  await upsert("price_recommendations_log", [
    {
      id: ids.priceLog1,
      parcel_id: ids.parcelInTransit,
      corridor_id: ids.corridorActive,
      factors: {
        route_key: "harare-cbd-borrowdale",
        distance_km: 5.2,
        size_code: "L",
        urgency: "URGENT"
      },
      recommended_price: 8.5,
      model_version: "v2"
    }
  ]);

  await upsert("route_pricing_history", [
    {
      id: ids.pricingHistory1,
      route_key: "harare-cbd-borrowdale",
      corridor_id: ids.corridorActive,
      parcel_id: ids.parcelInTransit,
      distance_meters: 5200,
      weight_kg: 11.6,
      size_code: "L",
      recommended_price: 8.5,
      accepted_price: 8.0
    }
  ]);

  await upsert("alert_rules", [
    {
      id: ids.alertRule1,
      type: "tracking_stalled",
      name: "Stalled Tracking Pulse",
      description: "Alert when tracking pulses stop for too long in Harare operations",
      enabled: true,
      severity: "warning",
      threshold: 10,
      time_window_minutes: 30,
      notification_channels: "in_app",
      is_active: true
    }
  ]);

  await upsert("alert_history", [
    {
      id: ids.alertHistory1,
      rule_id: ids.alertRule1,
      triggered_at: isoMinutesAgo(25),
      status: "triggered",
      message: "Courier stalled near Mbare Musika during demo run",
      details: {
        parcel_id: ids.parcelInTransit,
        courier_id: ids.courier1,
        zone: "Mbare"
      }
    }
  ]);

  await upsert("job_heartbeats", ids.heartbeats.map((jobName, index) => ({
    job_name: jobName,
    last_heartbeat_at: isoMinutesAgo(index * 2 + 1),
    expected_frequency_sec: 300,
    status: "ACTIVE",
    last_status_change_at: isoMinutesAgo(index * 2 + 1),
    created_by: ids.admin,
    request_id: "demo-seed"
  })), "job_name");

  await upsert("system_settings", [
    { key: "platform_city", value: { name: "Harare", country: "Zimbabwe" }, updated_by: ids.admin },
    { key: "map_provider", value: { provider: "openstreetmap", routing: "osrm" }, updated_by: ids.admin },
    { key: "notifications_mode", value: { mode: "in_app_push" }, updated_by: ids.admin },
    { key: "ops_banner", value: { text: "Harare demo environment active" }, updated_by: ids.admin }
  ], "key");

  await upsert("base_fares", [
    {
      id: "a2111111-1111-4111-8111-111111111111",
      corridor_name: "Harare CBD to Borrowdale",
      start_location: "Harare CBD",
      end_location: "Borrowdale",
      distance_km: 5.2,
      passenger_fare_usd: 3.5
    },
    {
      id: "a2111111-1111-4111-8111-111111111112",
      corridor_name: "Harare CBD to Mbare",
      start_location: "Harare CBD",
      end_location: "Mbare",
      distance_km: 4.1,
      passenger_fare_usd: 2.8
    },
    {
      id: "a2111111-1111-4111-8111-111111111113",
      corridor_name: "Borrowdale to CBD",
      start_location: "Borrowdale",
      end_location: "Harare CBD",
      distance_km: 5.2,
      passenger_fare_usd: 3.5
    }
  ]);

  await upsert("size_multipliers", [
    { id: "b2111111-1111-4111-8111-111111111111", size_code: "S", size_label: "Small", multiplier: 1.0 },
    { id: "b2111111-1111-4111-8111-111111111112", size_code: "M", size_label: "Medium", multiplier: 1.25 },
    { id: "b2111111-1111-4111-8111-111111111113", size_code: "L", size_label: "Large", multiplier: 1.55 },
    { id: "b2111111-1111-4111-8111-111111111114", size_code: "XL", size_label: "Extra Large", multiplier: 2.0 }
  ], "size_code");

  await upsert("connectivity_map", [
    {
      id: ids.connectivityMap1,
      courier_id: ids.courier1,
      lat: -17.8252,
      lng: 31.0335,
      network_provider: "Econet",
      device_model: "Samsung A04",
      signal_bucket: "GOOD",
      source: "tracking_pulse",
      observed_at: isoMinutesAgo(30)
    },
    {
      id: ids.connectivityMap2,
      courier_id: ids.courier2,
      lat: -17.7825,
      lng: 31.1030,
      network_provider: "NetOne",
      device_model: "Itel P681L",
      signal_bucket: "FAIR",
      source: "tracking_pulse",
      observed_at: isoMinutesAgo(20)
    }
  ]);

  await upsert("zone_connectivity", [
    {
      id: ids.zone1,
      zone_key: "harare-cbd",
      center_lat: -17.8252,
      center_lng: 31.0335,
      pulse_count: 48,
      poor_count: 3,
      offline_count: 1,
      score: 0.92
    },
    {
      id: ids.zone2,
      zone_key: "harare-mbare",
      center_lat: -17.8904,
      center_lng: 31.0531,
      pulse_count: 35,
      poor_count: 9,
      offline_count: 4,
      score: 0.68
    }
  ]);

  await upsert("connectivity_audit", [
    {
      id: ids.connAudit1,
      courier_id: ids.courier1,
      parcel_id: ids.parcelInTransit,
      lat: -17.8904,
      lng: 31.0531,
      source: "batch_sync_failure",
      reason: "harare-mbare-patchy-signal",
      age_ms: 78000,
      metadata: { zone: "Mbare", device: "Samsung A04" }
    },
    {
      id: ids.connAudit2,
      courier_id: ids.courier2,
      parcel_id: ids.parcelDelivered,
      lat: -17.8070,
      lng: 31.1050,
      source: "tracking_pulse_gap",
      reason: "harare-highlands-short-gap",
      age_ms: 22000,
      metadata: { zone: "Highlands", device: "Itel P681L" }
    },
    {
      id: ids.connAudit3,
      courier_id: ids.courier1,
      parcel_id: ids.parcelRequested,
      lat: -17.8252,
      lng: 31.0335,
      source: "batch_sync_failure",
      reason: "harare-cbd-transient-loss",
      age_ms: 50000,
      metadata: { zone: "CBD", device: "Samsung A04" }
    }
  ]);

  await upsert("error_logs", [
    {
      id: ids.error1,
      user_id: ids.client1,
      device_model: "Itel P681L",
      os_version: "Android 13",
      stack_trace: "ClientException: SocketException while loading map tiles in Harare CBD",
      context: { screen: "delivery_picker", city: "Harare" },
      request_id: "demo-error-001",
      occurred_at: isoMinutesAgo(95)
    },
    {
      id: ids.error2,
      user_id: ids.courier2,
      device_model: "Samsung A04",
      os_version: "Android 14",
      stack_trace: "Exception: LatLng is not finite: LatLng(latitude:NaN, longitude:NaN)",
      context: { screen: "map_route_declaration", city: "Harare" },
      request_id: "demo-error-002",
      occurred_at: isoMinutesAgo(80)
    }
  ]);

  await upsert("handshake_events", [
    {
      id: "d2111111-1111-4111-8111-111111111111",
      parcel_id: ids.parcelDelivered,
      step: "PICKUP",
      actor_id: ids.courier2,
      status: "SUCCESS",
      lat: -17.8070,
      lng: 31.1050,
      accuracy_m: 12,
      photo_url: "https://example.com/dropcity/demo/pickup-proof.jpg"
    },
    {
      id: "d2111111-1111-4111-8111-111111111112",
      parcel_id: ids.parcelDelivered,
      step: "DROPOFF",
      actor_id: ids.client1,
      status: "SUCCESS",
      lat: -17.7980,
      lng: 31.0285,
      accuracy_m: 10,
      photo_url: "https://example.com/dropcity/demo/dropoff-proof.jpg"
    }
  ]);

  await upsert("notifications", [
    {
      id: ids.notification1,
      type: "parcel_status",
      title: "Courier en route",
      body: "Your parcel is now moving through the Harare CBD corridor.",
      entity_type: "parcel",
      entity_id: ids.parcelInTransit,
      payload: { city: "Harare", status: "IN_TRANSIT" }
    },
    {
      id: ids.notification2,
      type: "route_start",
      title: "Start your journey",
      body: "Your Borrowdale corridor is ready to activate at 12:10.",
      entity_type: "route",
      entity_id: ids.routePlanned,
      payload: { city: "Harare", status: "PLANNED" }
    }
  ]);

  try {
    await upsert("notification_recipients", [
      {
        notification_id: ids.notification1,
        user_id: ids.client1,
        status: "unread",
        delivered_at: now.toISOString()
      },
      {
        notification_id: ids.notification1,
        user_id: ids.client2,
        status: "unread",
        delivered_at: now.toISOString()
      },
      {
        notification_id: ids.notification2,
        user_id: ids.courier1,
        status: "unread",
        delivered_at: now.toISOString()
      }
    ], "notification_id,user_id");
  } catch (error) {
    console.warn(`Skipping notification_recipients seed: ${error.message}`);
  }

  await upsert("profile_verification_audit", [
    {
      id: "e2111111-1111-4111-8111-111111111111",
      courier_id: ids.courier1,
      admin_id: ids.admin,
      action: "approved",
      reason: "Verified with demo paperwork and vehicle documents",
      documents_reviewed: ["id", "license", "vehicle_registration"],
      previous_status: "PENDING",
      new_status: "APPROVED"
    }
  ]);

  console.log("Harare demo seed completed successfully.");
}

seed().catch((error) => {
  console.error("Harare demo seed failed:", error.message);
  process.exitCode = 1;
});
