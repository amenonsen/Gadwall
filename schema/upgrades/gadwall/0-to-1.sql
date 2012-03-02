create table users (user_id serial primary key,login text unique,email text not null unique,password text not null,is_active bool not null default true,roles bit(31) not null default B'0'::bit(31));
