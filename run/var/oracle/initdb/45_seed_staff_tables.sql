ALTER SESSION SET CONTAINER=XEPDB1;
set serveroutput on

insert into ced3_owner.staff (staff_id, lastname, firstname, username, sp_status, email)
    values (100,'Admin','CED','cedadm','PRESENT', null);
insert into workgroup (workgroup_id, description, name)
   values (100,'CED Admin Group','cedadm');
insert into workgroup_membership (staff_id,workgroup_id)
    values (100,100);