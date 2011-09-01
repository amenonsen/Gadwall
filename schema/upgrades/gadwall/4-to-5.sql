begin;
    update schema set version='5' where name='gadwall';
    alter table users add second_last_login timestamptz;
commit;
