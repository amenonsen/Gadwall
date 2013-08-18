-- This table holds tags and an optional JSON object as a string. Each
-- row represents a job for utils/dequeued to handle (e.g. send mail).

create table queue (
    queue_id serial primary key,
    queued_at timestamptz not null
        default current_timestamp,
    tag text not null,
    data text
);
grant select, insert, delete on queue to :user;
grant select, usage on queue_queue_id_seq to :user;
