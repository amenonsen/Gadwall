begin;
    update schema set version=2 where name='gadwall';
    alter table confirmation_tokens add data text;
commit;
