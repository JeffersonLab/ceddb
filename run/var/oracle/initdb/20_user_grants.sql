ALTER SESSION SET CONTAINER=XEPDB1;
set serveroutput on
declare
    ced_schemas sys.dbms_debug_vc2coll
          := sys.dbms_debug_vc2coll('CED3_OWNER', 'CED3_DEVL', 'CED3_OPS', 'CED3_HIST');

    schema_user varchar2(20);

begin
for r in ced_schemas.first..ced_schemas.last
     loop
        schema_user := ced_schemas(r);
        dbms_output.put_line('Configure '||schema_user);
        EXECUTE IMMEDIATE 'alter user '||schema_user||' default tablespace ced quota unlimited on ced';
        EXECUTE IMMEDIATE 'grant create database link to '||schema_user;
        EXECUTE IMMEDIATE 'grant create dimension to '||schema_user;
        EXECUTE IMMEDIATE 'grant create job to '||schema_user;
        EXECUTE IMMEDIATE 'grant create library to '||schema_user;
        EXECUTE IMMEDIATE 'grant create procedure to '||schema_user;
        EXECUTE IMMEDIATE 'grant create sequence to '||schema_user;
        EXECUTE IMMEDIATE 'grant create session to '||schema_user;
        EXECUTE IMMEDIATE 'grant create synonym to '||schema_user;
        EXECUTE IMMEDIATE 'grant create table to '||schema_user;
        EXECUTE IMMEDIATE 'grant create trigger to '||schema_user;
        EXECUTE IMMEDIATE 'grant create type to '||schema_user;
        EXECUTE IMMEDIATE 'grant create view to '||schema_user;
        EXECUTE IMMEDIATE 'grant create cluster to '||schema_user;
        EXECUTE IMMEDIATE 'grant create materialized view to '||schema_user;
        EXECUTE IMMEDIATE 'grant READ_CED to '||schema_user;

        -- in order to create md5 hashes of blob values
        EXECUTE IMMEDIATE 'grant execute on dbms_crypto to '||schema_user;

        -- workspace manager
        EXECUTE IMMEDIATE 'grant select on wmsys.wm$modified_tables to '||schema_user;
        EXECUTE IMMEDIATE 'grant select on wmsys.wm$nextver_table to '||schema_user;
        EXECUTE IMMEDIATE 'grant select on wmsys.wm$version_hierarchy_table to '||schema_user;
        EXECUTE IMMEDIATE 'grant select on wmsys.wm$version_table to '||schema_user||' with grant option';
        EXECUTE IMMEDIATE 'grant select on wmsys.wm$workspaces_table to '||schema_user;

        EXECUTE IMMEDIATE 'grant connect to '||schema_user;
    end loop;
end;
/

