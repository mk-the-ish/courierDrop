-- Alert Management Tables
-- Stores alert rules and history of triggered alerts

create table if not exists alert_rules (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  name text not null,
  description text,
  enabled boolean not null default true,
  severity text not null default 'warning',
  threshold integer,
  time_window_minutes integer default 60,
  notification_channels text default 'slack',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists alert_history (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid not null references alert_rules(id) on delete cascade,
  triggered_at timestamptz not null default now(),
  status text not null,
  message text,
  details jsonb,
  created_at timestamptz not null default now()
);

-- Indexes for alert queries
create index if not exists alert_rules_enabled_idx on alert_rules(enabled);
create index if not exists alert_history_rule_id_idx on alert_history(rule_id);
create index if not exists alert_history_triggered_at_idx on alert_history(triggered_at desc);

-- Insert default alert rules
insert into alert_rules (type, name, description, threshold, time_window_minutes, severity, notification_channels)
values
  ('error_spike', 'High Error Volume', 'Alert when errors exceed 50 in 30 minutes', 50, 30, 'warning', 'slack,email'),
  ('stuck_job', 'Stuck Background Job', 'Alert when a scheduled job is stuck', null, null, 'critical', 'slack,email,sms'),
  ('high_failure_rate', 'Job Failure Rate', 'Alert when job failure rate exceeds 25%', 25, 60, 'warning', 'slack,email')
on conflict do nothing;
