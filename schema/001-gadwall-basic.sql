create table schema (name text primary key, version integer not null);
insert into schema (name, version) values ('gadwall', 3);

-- One row for each user who is allowed to login to the system

create table users (
    user_id serial primary key,
    login text unique,
    email text not null unique,
    password text,
    is_active bool not null default true,
    roles bit(31) not null default B'0'::bit(31)
);
grant select,insert,update on users to :user;
grant select,usage on users_user_id_seq to :user;

create table confirmation_tokens (
    token text primary key,
    path text not null,
    user_id integer not null references users
            on delete cascade,
    issued_at timestamptz not null
            default current_timestamp,
    data text,
    unique (path, user_id)
);
grant select,insert,delete on confirmation_tokens to :user;
