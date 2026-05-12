-- SMS Queue table for offline notification delivery
-- Stores pending SMS when network is unavailable or Twilio API fails

create table if not exists sms_queue (
  id uuid primary key default gen_random_uuid(),
  
  -- Recipient phone number in E.164 format (e.g., +263778123456)
  phone_number text not null,
  
  -- SMS message body
  message_body text not null,
  
  -- Context: 'pickup_confirmation', 'delivery_confirmation', 'alert', etc.
  context text not null,
  
  -- Foreign key references
  parcel_id uuid references parcels(id) on delete cascade,
  courier_id text references users(id) on delete cascade,
  customer_id text references users(id) on delete cascade,
  
  -- Delivery tracking
  delivery_status text default 'pending', -- pending, sent, failed, abandoned
  send_attempts integer default 0,
  max_attempts integer default 3,
  last_attempt_at timestamp with time zone,
  sent_at timestamp with time zone,
  error_message text,
  
  -- Metadata
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Indexes for efficient querying
create index if not exists idx_sms_queue_status on sms_queue(delivery_status);
create index if not exists idx_sms_queue_parcel_id on sms_queue(parcel_id);
create index if not exists idx_sms_queue_courier_id on sms_queue(courier_id);
create index if not exists idx_sms_queue_created_at on sms_queue(created_at);
create index if not exists idx_sms_queue_pending on sms_queue(delivery_status, send_attempts) where delivery_status = 'pending';

-- Trigger to auto-update updated_at
create or replace function update_sms_queue_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger sms_queue_timestamp_trigger
before update on sms_queue
for each row
execute function update_sms_queue_timestamp();

-- RPC function to enqueue SMS
create or replace function enqueue_sms(
  p_phone_number text,
  p_message_body text,
  p_context text,
  p_parcel_id uuid default null,
  p_courier_id text default null,
  p_customer_id text default null
)
returns json as $$
declare
  v_sms_id uuid;
begin
  insert into sms_queue (
    phone_number,
    message_body,
    context,
    parcel_id,
    courier_id,
    customer_id
  ) values (
    p_phone_number,
    p_message_body,
    p_context,
    p_parcel_id,
    p_courier_id,
    p_customer_id
  )
  returning id into v_sms_id;
  
  return json_build_object(
    'id', v_sms_id,
    'status', 'enqueued',
    'phone_number', p_phone_number,
    'context', p_context
  );
end;
$$ language plpgsql;

-- RPC function to mark SMS as sent
create or replace function mark_sms_sent(p_sms_id uuid)
returns json as $$
begin
  update sms_queue
  set
    delivery_status = 'sent',
    sent_at = now(),
    updated_at = now()
  where id = p_sms_id;
  
  return json_build_object('id', p_sms_id, 'delivery_status', 'sent');
end;
$$ language plpgsql;

-- RPC function to mark SMS as failed and increment attempts
create or replace function mark_sms_failed(
  p_sms_id uuid,
  p_error_message text
)
returns json as $$
declare
  v_new_attempt_count integer;
  v_new_status text;
begin
  update sms_queue
  set
    send_attempts = send_attempts + 1,
    last_attempt_at = now(),
    error_message = p_error_message,
    delivery_status = case
      when (send_attempts + 1) >= max_attempts then 'abandoned'
      else 'pending'
    end,
    updated_at = now()
  where id = p_sms_id
  returning send_attempts, delivery_status into v_new_attempt_count, v_new_status;
  
  return json_build_object(
    'id', p_sms_id,
    'attempt', v_new_attempt_count,
    'status', v_new_status,
    'error', p_error_message
  );
end;
$$ language plpgsql;

-- RPC function to get pending SMS for batch processing
create or replace function get_pending_sms(
  p_limit integer default 50
)
returns table (
  id uuid,
  phone_number text,
  message_body text,
  context text,
  parcel_id uuid,
  courier_id text,
  customer_id text,
  send_attempts integer,
  max_attempts integer
) as $$
begin
  return query
  select
    sms_queue.id,
    sms_queue.phone_number,
    sms_queue.message_body,
    sms_queue.context,
    sms_queue.parcel_id,
    sms_queue.courier_id,
    sms_queue.customer_id,
    sms_queue.send_attempts,
    sms_queue.max_attempts
  from sms_queue
  where delivery_status = 'pending'
  order by created_at asc
  limit p_limit;
end;
$$ language plpgsql;
