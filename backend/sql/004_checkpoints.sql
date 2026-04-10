create or replace function generate_parcel_checkpoints(
  p_parcel_id uuid,
  p_count integer default 3,
  p_radius_m integer default 200
)
returns void
language plpgsql
as $$
declare
  pickup geography;
  dropoff geography;
  line geometry;
  i integer;
  fraction double precision;
begin
  select pickup_point, dropoff_point
    into pickup, dropoff
  from parcels
  where id = p_parcel_id;

  if pickup is null or dropoff is null then
    raise exception 'Pickup or dropoff point missing';
  end if;

  line := st_makeline(pickup::geometry, dropoff::geometry);

  delete from parcel_checkpoints where parcel_id = p_parcel_id;

  for i in 0..(p_count - 1) loop
    if p_count = 1 then
      fraction := 0.5;
    else
      fraction := i::double precision / (p_count - 1);
    end if;
    insert into parcel_checkpoints(parcel_id, sequence, checkpoint_point, radius_m)
    values (
      p_parcel_id,
      i + 1,
      st_lineinterpolatepoint(line, fraction)::geography,
      p_radius_m
    );
  end loop;
end;
$$;
