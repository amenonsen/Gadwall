-- One row for each user who is allowed to login to the system

create table users (
    user_id serial primary key,
    login text unique,
    email text not null unique,
    name text,
    password text,
    is_active bool not null default true,
    roles bit(31) not null default B'0'::bit(31),
    last_login timestamptz,
    second_last_login timestamptz,
    last_failed_login timestamptz,
    last_password_change timestamptz,
    consecutive_failures integer not null
        default 0
);
grant select,insert,update on users to :user;
grant select,usage on users_user_id_seq to :user;

-- One row for each random token that allows the specified user access
-- to the given path with some optional associated data. The token is
-- valid for a specified number of uses, or a period of time, or both.

create table confirmation_tokens (
    token text primary key,
    path text not null,
    user_id integer not null references users
            on delete cascade,
    issued_at timestamptz not null
            default current_timestamp,
    valid_for interval default interval '1 hour',
    remaining_uses integer default 1,
    data text,
    unique (path, user_id)
);
grant select,insert,update,delete on confirmation_tokens to :user;
