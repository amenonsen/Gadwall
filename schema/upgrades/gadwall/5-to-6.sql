grant select,insert,update,delete on confirmation_tokens to :user;
alter table confirmation_tokens add valid_for interval default interval '1 hour';
alter table confirmation_tokens add total_uses integer default 1;
