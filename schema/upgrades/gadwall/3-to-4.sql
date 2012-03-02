alter table users add last_login timestamptz;
alter table users add last_failed_login timestamptz;
alter table users add last_password_change timestamptz;
alter table users add consecutive_failures int not null default 0;
