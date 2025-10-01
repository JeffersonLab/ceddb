ALTER SESSION SET CONTAINER=XEPDB1;

; CATEGORY_ID
drop sequence ced3_devl.CATEGORY_ID;
create sequence ced3_devl.CATEGORY_ID start with 1000;
grant select on ced3_devl.category_id to read_ced;


;CMPNT_ID
drop sequence ced3_devl.CMPNT_ID;
create sequence ced3_devl.cmpnt_id start with 100000;
grant select on ced3_devl.cmpnt_id to read_ced;

;CMPNT_TYPE_ID
drop sequence ced3_devl.CMPNT_TYPE_ID;
create sequence ced3_devl.cmpnt_type_id start with 2000000;
grant select on ced3_devl.cmpnt_type_id to read_ced;

;CMPNT_TYPE_PROP_ID
drop sequence ced3_devl.CMPNT_TYPE_PROP_ID;
create sequence ced3_devl.cmpnt_type_prop_id start with 5000;
grant select on ced3_devl.cmpnt_type_prop_id to read_ced;


;SEGMENT_ID
drop sequence ced3_devl.segment_id;
create sequence ced3_devl.segment_id start with 500;
grant select on ced3_devl.segment_id to read_ced;


;SET_ID
drop sequence ced3_devl.set_id;
create sequence ced3_devl.set_id start with 500;
grant select on ced3_devl.set_id to read_ced;


;ZONE_ID
drop sequence ced3_devl.zone_id;
create sequence ced3_devl.zone_id start with 5000;
grant select on ced3_devl.zone_id to read_ced;

;ZONE_LINKS_ID
drop sequence ced3_devl.zone_links_id;
create sequence ced3_devl.zone_links_id start with 5000;
grant select on ced3_devl.zone_links_id to read_ced;

;EVENT_ID
drop sequence ced3_ops.EVENT_ID;
create sequence ced3_ops.event_id start with 50000;
grant select on ced3_ops.event_id to read_ced;