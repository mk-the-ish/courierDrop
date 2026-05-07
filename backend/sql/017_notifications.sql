create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  title text not null,
  body text not null,
  entity_type text,
  entity_id text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists notification_recipients (
  notification_id uuid not null,
  user_id uuid not null,
  status text not null default 'unread',
  read_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (notification_id, user_id),
  constraint notification_recipients_notification_fk
    foreign key (notification_id)
    references notifications(id)
    on delete cascade
);

create table if not exists notification_outbox (
  id bigserial primary key,
  kind text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  attempts integer not null default 0,
  last_error text,
  run_after timestamptz not null default now(),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists idx_notification_recipients_user_status_created
  on notification_recipients (user_id, status, created_at desc);

create index if not exists idx_notification_outbox_status_run_after_created
  on notification_outbox (status, run_after, created_at);
