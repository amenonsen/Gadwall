begin;
    update schema set version='3' where name='gadwall';
    alter table users alter password drop not null;
commit;
