-- One row per arbitrary component of the schema with an integer version
-- number. A component is a piece of the schema that it might be useful
-- to upgrade independently.

create table schema (
    name text primary key,
    version integer not null
);

insert into schema (name, version) values
    ('gadwall', 9);
