create table queue (
    queue_id serial primary key,
    queued_at timestamptz not null
        default current_timestamp,
    tag text not null,
    data text
);
