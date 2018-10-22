
PROMPT '*******************************************'
PROMPT '* NOTE: This script must be run as sysdba *'
PROMPT '*******************************************'
PROMPT

ACCEPT CEDUSER char PROMPT 'Enter the schema owner to create >'
ACCEPT PASSWORD char PROMPT 'Enter the schema password to set >'

set verify off
set echo off


create user &CEDUSER identified by "&&PASSWORD"
default tablespace "CED"
temporary tablespace "TEMP"
quota unlimited on "CED" account unlock;


grant create database link to &CEDUSER;
grant create dimension to &CEDUSER;
grant create job to &CEDUSER;
grant create library to &CEDUSER;
grant create procedure to &CEDUSER;
grant create sequence to &CEDUSER;
grant create session to &CEDUSER;
grant create synonym to &CEDUSER;
grant create table to &CEDUSER;
grant create trigger to &CEDUSER;
grant create type to &CEDUSER;
grant create view to &CEDUSER;
grant create cluster to &CEDUSER;
grant create materialized view to &CEDUSER;


grant READ_CED to &CEDUSER;

-- With Workspaces enabled only full exports are possible!
-- Hence we run CED in its own instance and no other users.
-- grant EXP_FULL_DATABASE to &CEDUSER;

-- in order to create md5 hashes of blob values
grant execute on dbms_crypto to &CEDUSER;


grant select on wmsys.wm$modified_tables to &CEDUSER;
grant select on wmsys.wm$nextver_table to &CEDUSER;
grant select on wmsys.wm$version_hierarchy_table to &CEDUSER;
grant select on wmsys.wm$version_table to &CEDUSER with grant option;
grant select on wmsys.wm$workspaces_table to &CEDUSER;

grant connect to &CEDUSER;


