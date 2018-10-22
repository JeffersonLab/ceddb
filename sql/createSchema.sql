
/**
* NOTE:  This schema is maintained through ERWin.  Do not hand-edit!!!!
*    Any changes made directly to this file will be lost!.
*       
*/



-- These procedures are created via the enable
DROP MATERIALIZED VIEW mv_cmpnt_prop_val_live;

-- If versioning is still enabled, the drops at the beginning of the
-- create script will fail.  We try to turn it off here. 

EXECUTE DBMS_WM.DisableVersioning ('cmpnt_type, cmpnt_type_owners, cmpnt, cmpnt_owners, cmpnt_type_prop, cmpnt_prop, cmpnt_type_prop_def, cmpnt_type_prop_dom, cmpnt_type_prop_dim, cmpnt_type_prop_req, cmpnt_type_prop_owners, cmpnt_type_prop_cats, category_sets, cmpnt_prop_fk_cmpnt, cmpnt_prop_bool, cmpnt_prop_integer, cmpnt_prop_float, cmpnt_prop_string, cmpnt_prop_date, cmpnt_prop_blob, zones, zone_links, segments');


DROP DATABASE LINK prod01;

DROP SEQUENCE category_id;

CREATE SEQUENCE category_id
    INCREMENT BY 1
    START WITH 10;

DROP SEQUENCE cmpnt_id;

CREATE SEQUENCE cmpnt_id
    INCREMENT BY 1
    START WITH 1000;

DROP SEQUENCE cmpnt_prop_id;

CREATE SEQUENCE cmpnt_prop_id
    INCREMENT BY 1
    START WITH 1000;

DROP SEQUENCE cmpnt_type_id;

CREATE SEQUENCE cmpnt_type_id
    INCREMENT BY 1000
    START WITH 10000;

DROP SEQUENCE cmpnt_type_prop_id;

CREATE SEQUENCE cmpnt_type_prop_id
    INCREMENT BY 1
    START WITH 1000;

DROP SEQUENCE event_id;

CREATE SEQUENCE event_id
    INCREMENT BY 1
    START WITH 1;

DROP SEQUENCE history_seq;

CREATE SEQUENCE history_seq
    INCREMENT BY 1
    START WITH 1
    NOCACHE;

DROP SEQUENCE log_id;

CREATE SEQUENCE log_id
    INCREMENT BY 1
    START WITH 1;

DROP SEQUENCE segment_id;

CREATE SEQUENCE segment_id
    INCREMENT BY 1
    START WITH 1;

DROP SEQUENCE set_id;

CREATE SEQUENCE set_id
    INCREMENT BY 1
    START WITH 100;

DROP SEQUENCE value_id;

CREATE SEQUENCE value_id
    INCREMENT BY 1
    START WITH 1000;

DROP SEQUENCE zone_id;

CREATE SEQUENCE zone_id
    INCREMENT BY 1
    START WITH 1;

DROP SEQUENCE zone_links_id;

CREATE SEQUENCE zone_links_id
    INCREMENT BY 10
    START WITH 10;

DROP TABLE cmpnt_prop_blob CASCADE CONSTRAINTS PURGE;

DROP TABLE zone_links CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_type_prop_req CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_type_prop_dom CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_prop_string CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_type_prop_dim CASCADE CONSTRAINTS PURGE;

DROP TABLE workspace_info CASCADE CONSTRAINTS PURGE;

DROP TABLE admin_log CASCADE CONSTRAINTS PURGE;

DROP TABLE admin_lock CASCADE CONSTRAINTS PURGE;

DROP TABLE hist_cmpnt_prop_val CASCADE CONSTRAINTS PURGE;

DROP TABLE hist_cmpnt_prop CASCADE CONSTRAINTS PURGE;

DROP TABLE hist_cmpnt CASCADE CONSTRAINTS PURGE;

DROP TABLE merge_log CASCADE CONSTRAINTS PURGE;

DROP TABLE web_auth CASCADE CONSTRAINTS PURGE;

DROP TABLE CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_prop_fk_cmpnt CASCADE CONSTRAINTS PURGE;

DROP TABLE usage_log CASCADE CONSTRAINTS PURGE;

DROP TABLE segments CASCADE CONSTRAINTS PURGE;

DROP TABLE zones CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_type_prop_owners CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_owners CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_prop_integer CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_type_prop_def CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_prop_float CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_prop_date CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_type_owners CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_prop_bool CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_prop CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_type_prop CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_type_prop_cats CASCADE CONSTRAINTS PURGE;

DROP TABLE category_sets CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt CASCADE CONSTRAINTS PURGE;

DROP TABLE cmpnt_type CASCADE CONSTRAINTS PURGE;

CREATE TABLE admin_lock
(
    lck                  INTEGER DEFAULT  1  NOT NULL ,
    username             VARCHAR2(20) NOT NULL ,
    lck_created          DATE NOT NULL ,
    lck_comments         VARCHAR2(500) NULL ,
    block_live_edit      INTEGER DEFAULT  0  NULL 
);

COMMENT ON TABLE admin_lock IS 'Table used to create an advisory lock to help prevent two CED administrators from trying to merge data or copy data to OPS at the same time.';

COMMENT ON COLUMN admin_lock.lck IS 'Only valid value is 1.  Row must be deleted to release the lock.';

COMMENT ON COLUMN admin_lock.username IS 'Username who created the lock';

COMMENT ON COLUMN admin_lock.lck_created IS 'When the lock was created';

COMMENT ON COLUMN admin_lock.lck_comments IS 'Comments about why the lock was created';

ALTER TABLE admin_lock
    ADD CONSTRAINT  XPKadmin_lock PRIMARY KEY (lck);

ALTER TABLE admin_lock
    MODIFY lck CONSTRAINT  Only_1_159 CHECK (lck IN (1));

ALTER TABLE admin_lock
    MODIFY block_live_edit CONSTRAINT  Valid_Boolean_1350034183 CHECK (block_live_edit IN (0, 1));

CREATE TABLE admin_log
(
    logdate              DATE NULL ,
    logmsg               VARCHAR2(4000) NULL ,
    log_id               INTEGER NOT NULL 
);

COMMENT ON TABLE admin_log IS 'Logs output from administrative events.  Used by procedures in the CED_ADMIN package to log actions and errors';

ALTER TABLE admin_log
    ADD CONSTRAINT  XPKadmin_log PRIMARY KEY (log_id);

CREATE TABLE category_sets
(
    set_id               INTEGER NOT NULL ,
    name                 VARCHAR2(20) NOT NULL ,
    ordering             INTEGER DEFAULT  100  NOT NULL 
);

COMMENT ON TABLE category_sets IS 'Category sets are used to group related categories.  For example Model and Twiss categories might belogn to the Design set.';

COMMENT ON COLUMN category_sets.set_id IS 'Primary key';

COMMENT ON COLUMN category_sets.name IS 'Name of the set.  Must be unique (case-insensitive)';

COMMENT ON COLUMN category_sets.ordering IS 'Provides relative ordering of sets.  Lower numbers will be displayed before higher numbers.';

ALTER TABLE category_sets
    ADD CONSTRAINT  XPKcategory_sets PRIMARY KEY (set_id);

CREATE UNIQUE INDEX XAK1category_sets ON category_sets
(name   ASC);

ALTER TABLE category_sets
ADD CONSTRAINT  XAK1category_sets UNIQUE (name);

ALTER TABLE category_sets
    MODIFY ordering CONSTRAINT  Pos_Int_910162419 CHECK (ordering >= 0);

CREATE TABLE cmpnt
(
    cmpnt_id             INTEGER NOT NULL ,
    cmpnt_type_id        INTEGER NOT NULL ,
    name                 VARCHAR2(255) NULL 
)
    CACHE
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt IS 'Stores the master list of Accelerator Components. Components may be physical (ex: Magnets, Power Supplies, Racks, Chassis, etc.) or logical (ex: Field Maps)';

COMMENT ON COLUMN cmpnt.cmpnt_id IS 'The unique database handle for the component.';

COMMENT ON COLUMN cmpnt.cmpnt_type_id IS 'Identifies the type of the component (see cmpnt_type table)';

COMMENT ON COLUMN cmpnt.name IS 'The name of the component (Required).
Must be unique and satisfy the regex constraint: ''^[A-Za-z0-9\._-]+$''';

ALTER TABLE cmpnt
    ADD CONSTRAINT  XPKcmpnt PRIMARY KEY (cmpnt_id);

CREATE UNIQUE INDEX XAK1cmpnt_name ON cmpnt
(name   ASC);

ALTER TABLE cmpnt
    MODIFY name CONSTRAINT  cmpnt_name_validchar_1 CHECK (regexp_like(name, '^[A-Za-z0-9\._-]+$'));

CREATE INDEX XIF1cmpnt ON cmpnt
(cmpnt_type_id   ASC);

CREATE TABLE cmpnt_owners
(
    cmpnt_id             INTEGER NOT NULL ,
    owner                VARCHAR2(20) NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_owners IS 'Identifies users or groups who may set or modify properties of a specific cmpnt.';

COMMENT ON COLUMN cmpnt_owners.cmpnt_id IS 'The unique database handle for the component.';

COMMENT ON COLUMN cmpnt_owners.owner IS 'The unix username or group name.  By convention group names are prefixed with $ to distinquish them from usernames.';

ALTER TABLE cmpnt_owners
    ADD CONSTRAINT  XPKcmpnt_owners PRIMARY KEY (cmpnt_id,owner);

CREATE TABLE cmpnt_prop
(
    cmpnt_id             INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    comments             VARCHAR2(512) NULL ,
    modify_date          TIMESTAMP DEFAULT  CURRENT_TIMESTAMP  NULL ,
    set_by               VARCHAR2(20) NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_prop IS 'Stores the properties specific to an instance of a component. For example the HGAP value of Magnet MAA3R01 or the IP Address of iocch2.  The actual data value must be looked up in the cmpnt_prop_float, cmpnt_prop_string, etc. table depending upon its datatype.';

COMMENT ON COLUMN cmpnt_prop.cmpnt_id IS 'The unique database handle for the component.';

COMMENT ON COLUMN cmpnt_prop.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_prop.comments IS 'Explanatory text about the value, why it is set, etc.';

COMMENT ON COLUMN cmpnt_prop.modify_date IS 'The date the current value was set';

COMMENT ON COLUMN cmpnt_prop.set_by IS 'The username of the person who set the property value';

ALTER TABLE cmpnt_prop
    ADD CONSTRAINT  XPKcmpnt_prop PRIMARY KEY (cmpnt_id,cmpnt_type_prop_id);

CREATE INDEX XIF2cmpnt_prop ON cmpnt_prop
(cmpnt_id   ASC);

CREATE INDEX XIF3cmpnt_prop ON cmpnt_prop
(cmpnt_type_prop_id   ASC);

CREATE INDEX XIE1cmpnt_prop ON cmpnt_prop
(modify_date   ASC);

CREATE TABLE cmpnt_prop_blob
(
    cmpnt_id             INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    value                BLOB NOT NULL ,
    mime_type            VARCHAR2(255) NULL ,
    value_id             INTEGER NULL ,
    dim1                 INTEGER DEFAULT  0  NOT NULL ,
    dim2                 INTEGER DEFAULT  0  NOT NULL ,
    value_md5            VARCHAR2(32) NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_prop_blob IS 'Stores bulk data values, possibly of binary format.';

COMMENT ON COLUMN cmpnt_prop_blob.cmpnt_id IS 'The unique database handle for the component.';

COMMENT ON COLUMN cmpnt_prop_blob.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_prop_blob.value IS 'The data payload';

COMMENT ON COLUMN cmpnt_prop_blob.mime_type IS 'Used to identify the type of content stored in value and the program which creates or uses it.';

COMMENT ON COLUMN cmpnt_prop_blob.value_id IS 'deprecated column.  Will be dropped in the future.';

COMMENT ON COLUMN cmpnt_prop_blob.dim1 IS 'Array dimension 1
Typically used for multi-pass properties, but generally useful for creating a general purpose vector of values.';

COMMENT ON COLUMN cmpnt_prop_blob.dim2 IS 'Array dimension 2
(Added to schema priort to enableVersioning in anticipation of future API support.)';

COMMENT ON COLUMN cmpnt_prop_blob.value_md5 IS 'Column to store a hash of the blob value to speed and ease comparisons among CED installations.';

ALTER TABLE cmpnt_prop_blob
    ADD CONSTRAINT  XPKcmpnt_prop_blob PRIMARY KEY (cmpnt_id,cmpnt_type_prop_id,dim1,dim2);

ALTER TABLE cmpnt_prop_blob
    MODIFY dim1 CONSTRAINT  Pos_Int_859962113 CHECK (dim1 >= 0);

ALTER TABLE cmpnt_prop_blob
    MODIFY dim2 CONSTRAINT  Pos_Int_876739329 CHECK (dim2 >= 0);

CREATE TABLE cmpnt_prop_bool
(
    cmpnt_id             INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    value                SMALLINT NOT NULL ,
    value_id             INTEGER NULL ,
    dim1                 INTEGER DEFAULT  0  NOT NULL ,
    dim2                 INTEGER DEFAULT  0  NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_prop_bool IS 'Stores cmpnt_prop boolean values. Because Oracle has no native boolean datatype, we use a table constraint to enforce storage of either integer 0 (false) or integer 1 (true)';

COMMENT ON COLUMN cmpnt_prop_bool.cmpnt_id IS 'The unique database handle for the component.';

COMMENT ON COLUMN cmpnt_prop_bool.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_prop_bool.value IS '0/1';

COMMENT ON COLUMN cmpnt_prop_bool.value_id IS 'deprecated column.  Will be dropped in the future.';

COMMENT ON COLUMN cmpnt_prop_bool.dim1 IS 'Array dimension 1
Typically used for multi-pass properties, but generally useful for creating a general purpose vector of values.';

COMMENT ON COLUMN cmpnt_prop_bool.dim2 IS 'Array dimension 2
(Added to schema priort to enableVersioning in anticipation of future API support.)';

ALTER TABLE cmpnt_prop_bool
    ADD CONSTRAINT  XPKcmpnt_prop_bool PRIMARY KEY (cmpnt_id,cmpnt_type_prop_id,dim1,dim2);

ALTER TABLE cmpnt_prop_bool
    MODIFY value CONSTRAINT  Valid_Boolean_1177967024 CHECK (value IN (0, 1));

ALTER TABLE cmpnt_prop_bool
    MODIFY dim1 CONSTRAINT  Pos_Int_1027735041 CHECK (dim1 >= 0);

ALTER TABLE cmpnt_prop_bool
    MODIFY dim2 CONSTRAINT  Pos_Int_1044512257 CHECK (dim2 >= 0);

CREATE INDEX XIE1cmpnt_prop_bool ON cmpnt_prop_bool
(value   ASC);

CREATE TABLE cmpnt_prop_date
(
    cmpnt_id             INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    value                DATE NOT NULL ,
    value_id             INTEGER NULL ,
    dim1                 INTEGER DEFAULT  0  NOT NULL ,
    dim2                 INTEGER DEFAULT  0  NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_prop_date IS 'Stores cmpnt_prop date values';

COMMENT ON COLUMN cmpnt_prop_date.cmpnt_id IS 'The unique database handle for the component.';

COMMENT ON COLUMN cmpnt_prop_date.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_prop_date.value_id IS 'deprecated column.  Will be dropped in the future.';

COMMENT ON COLUMN cmpnt_prop_date.dim1 IS 'Array dimension 1
Typically used for multi-pass properties, but generally useful for creating a general purpose vector of values.';

COMMENT ON COLUMN cmpnt_prop_date.dim2 IS 'Array dimension 2
(Added to schema priort to enableVersioning in anticipation of future API support.)';

ALTER TABLE cmpnt_prop_date
    ADD CONSTRAINT  XPKcmpnt_prop_date PRIMARY KEY (cmpnt_id,cmpnt_type_prop_id,dim1,dim2);

ALTER TABLE cmpnt_prop_date
    MODIFY dim1 CONSTRAINT  Pos_Int_910422022 CHECK (dim1 >= 0);

ALTER TABLE cmpnt_prop_date
    MODIFY dim2 CONSTRAINT  Pos_Int_927199238 CHECK (dim2 >= 0);

CREATE INDEX XIE1cmpnt_prop_date ON cmpnt_prop_date
(value   ASC);

CREATE TABLE cmpnt_prop_fk_cmpnt
(
    cmpnt_id             INTEGER NOT NULL ,
    value                INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    value_id             INTEGER NULL ,
    dim1                 INTEGER DEFAULT  0  NOT NULL ,
    dim2                 INTEGER DEFAULT  0  NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_prop_fk_cmpnt IS 'This table is used to track cmpnt_prop_values that are references to other cmpnt.  By having a dedicated table with Foreign Key constraint, it will be possible to avoid having dangling references to renamed/removed cmpnts.';

COMMENT ON COLUMN cmpnt_prop_fk_cmpnt.cmpnt_id IS 'The unique database handle for the component.';

COMMENT ON COLUMN cmpnt_prop_fk_cmpnt.value IS 'The cmpnt_id of another row in the cmpnt table.  The API must guard against self-referential cycles here.';

COMMENT ON COLUMN cmpnt_prop_fk_cmpnt.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_prop_fk_cmpnt.value_id IS 'deprecated column.  Will be dropped in the future.';

COMMENT ON COLUMN cmpnt_prop_fk_cmpnt.dim1 IS 'Array dimension 1
Typically used for multi-pass properties, but generally useful for creating a general purpose vector of values.';

COMMENT ON COLUMN cmpnt_prop_fk_cmpnt.dim2 IS 'Array dimension 2
(Added to schema priort to enableVersioning in anticipation of future API support.)';

ALTER TABLE cmpnt_prop_fk_cmpnt
    ADD CONSTRAINT  XPKcmpnt_prop_fk_cmpnt PRIMARY KEY (cmpnt_id,cmpnt_type_prop_id,dim1,dim2);

ALTER TABLE cmpnt_prop_fk_cmpnt
    MODIFY dim1 CONSTRAINT  Pos_Int_1464636833 CHECK (dim1 >= 0);

ALTER TABLE cmpnt_prop_fk_cmpnt
    MODIFY dim2 CONSTRAINT  Pos_Int_1447859617 CHECK (dim2 >= 0);

CREATE INDEX XIE1cmpnt_prop_fk_cmpnt ON cmpnt_prop_fk_cmpnt
(value   ASC);

CREATE TABLE cmpnt_prop_float
(
    cmpnt_id             INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    value                NUMBER NOT NULL ,
    value_id             INTEGER NULL ,
    dim1                 INTEGER DEFAULT  0  NOT NULL ,
    dim2                 INTEGER DEFAULT  0  NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_prop_float IS 'Stores cmpnt_prop floating point values.';

COMMENT ON COLUMN cmpnt_prop_float.cmpnt_id IS 'The unique database handle for the component.';

COMMENT ON COLUMN cmpnt_prop_float.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_prop_float.value_id IS 'deprecated column.  Will be dropped in the future.';

COMMENT ON COLUMN cmpnt_prop_float.dim1 IS 'Array dimension 1
Typically used for multi-pass properties, but generally useful for creating a general purpose vector of values.';

COMMENT ON COLUMN cmpnt_prop_float.dim2 IS 'Array dimension 2
(Added to schema priort to enableVersioning in anticipation of future API support.)';

ALTER TABLE cmpnt_prop_float
    ADD CONSTRAINT  XPKcmpnt_prop_float PRIMARY KEY (cmpnt_id,cmpnt_type_prop_id,dim1,dim2);

ALTER TABLE cmpnt_prop_float
    MODIFY dim1 CONSTRAINT  Pos_Int_1286730742 CHECK (dim1 >= 0);

ALTER TABLE cmpnt_prop_float
    MODIFY dim2 CONSTRAINT  Pos_Int_1303507958 CHECK (dim2 >= 0);

CREATE INDEX XIE1cmpnt_prop_float ON cmpnt_prop_float
(value   ASC);

CREATE TABLE cmpnt_prop_integer
(
    cmpnt_id             INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    value                INTEGER NOT NULL ,
    value_id             INTEGER NULL ,
    dim1                 INTEGER DEFAULT  0  NOT NULL ,
    dim2                 INTEGER DEFAULT  0  NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_prop_integer IS 'Stores cmpnt_prop integer values.';

COMMENT ON COLUMN cmpnt_prop_integer.cmpnt_id IS 'The unique database handle for the component.';

COMMENT ON COLUMN cmpnt_prop_integer.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_prop_integer.value_id IS 'deprecated column.  Will be dropped in the future.';

COMMENT ON COLUMN cmpnt_prop_integer.dim1 IS 'Array dimension 1
Typically used for multi-pass properties, but generally useful for creating a general purpose vector of values.';

COMMENT ON COLUMN cmpnt_prop_integer.dim2 IS 'Array dimension 2
(Added to schema priort to enableVersioning in anticipation of future API support.)';

ALTER TABLE cmpnt_prop_integer
    ADD CONSTRAINT  XPKcmpnt_prop_integer PRIMARY KEY (cmpnt_id,cmpnt_type_prop_id,dim1,dim2);

ALTER TABLE cmpnt_prop_integer
    MODIFY dim1 CONSTRAINT  Pos_Int_1264322193 CHECK (dim1 >= 0);

ALTER TABLE cmpnt_prop_integer
    MODIFY dim2 CONSTRAINT  Pos_Int_1247544977 CHECK (dim2 >= 0);

CREATE INDEX XIE1cmpnt_prop_integer ON cmpnt_prop_integer
(value   ASC);

CREATE TABLE cmpnt_prop_string
(
    cmpnt_id             INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    value                VARCHAR2(4000) NOT NULL ,
    value_id             INTEGER NULL ,
    dim1                 INTEGER DEFAULT  0  NOT NULL ,
    dim2                 INTEGER DEFAULT  0  NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_prop_string IS 'Stores cmpnt_prop string values. Limited by oracle varchar2 column type to no more than 4000 characters.';

COMMENT ON COLUMN cmpnt_prop_string.cmpnt_id IS 'The unique database handle for the component.';

COMMENT ON COLUMN cmpnt_prop_string.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_prop_string.value_id IS 'deprecated column.  Will be dropped in the future.';

COMMENT ON COLUMN cmpnt_prop_string.dim1 IS 'Array dimension 1
Typically used for multi-pass properties, but generally useful for creating a general purpose vector of values.';

COMMENT ON COLUMN cmpnt_prop_string.dim2 IS 'Array dimension 2
(Added to schema priort to enableVersioning in anticipation of future API support.)';

ALTER TABLE cmpnt_prop_string
    ADD CONSTRAINT  XPKcmpnt_prop_string PRIMARY KEY (cmpnt_id,cmpnt_type_prop_id,dim1,dim2);

ALTER TABLE cmpnt_prop_string
    MODIFY dim1 CONSTRAINT  Pos_Int_1280446185 CHECK (dim1 >= 0);

ALTER TABLE cmpnt_prop_string
    MODIFY dim2 CONSTRAINT  Pos_Int_1263668969 CHECK (dim2 >= 0);

CREATE INDEX XIE1cmpnt_prop_string ON cmpnt_prop_string
(value   ASC);

CREATE TABLE cmpnt_type
(
    cmpnt_type_id        INTEGER NOT NULL ,
    parent_cmpnt_type_id INTEGER NULL ,
    name                 VARCHAR2(60) NOT NULL ,
    description          VARCHAR2(4000) NULL ,
    is_abstract          SMALLINT DEFAULT  0  NULL ,
    name_limit           VARCHAR2(512) NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_type IS 'Identifies the types of components that may be stored in the cmpnt table.';

COMMENT ON COLUMN cmpnt_type.cmpnt_type_id IS 'The unique database handle for the component type';

COMMENT ON COLUMN cmpnt_type.parent_cmpnt_type_id IS 'Allows for hierarchy of component types. Its value is the cmpnt_type_id from which it inherits';

COMMENT ON COLUMN cmpnt_type.name IS 'A unique name for the component type, for use by humans';

COMMENT ON COLUMN cmpnt_type.description IS 'text describing the component type and its usage, peculiarities, etc.';

COMMENT ON COLUMN cmpnt_type.is_abstract IS 'Set to true (1) for cmpnt_types used for inheritance purposes only';

COMMENT ON COLUMN cmpnt_type.name_limit IS 'Optionally stores a regular expression that can be used to limit valid names for the instances of the type.  For example to enforce that all instances of type IOC must begin with the three lower case letters ioc and be followed only by alphanumeric characters: ^ioc[a-zA-Z0-0]*$';

ALTER TABLE cmpnt_type
    ADD CONSTRAINT  XPKcmpnt_type PRIMARY KEY (cmpnt_type_id)  ENABLE;

CREATE UNIQUE INDEX XAK1cmpnt_type ON cmpnt_type
(name   ASC);

ALTER TABLE cmpnt_type
ADD CONSTRAINT  XAK1cmpnt_type UNIQUE (name)  ENABLE;

ALTER TABLE cmpnt_type
    MODIFY is_abstract CONSTRAINT  Valid_Boolean_1061603998 CHECK (is_abstract IN (0, 1));

CREATE INDEX XIF1cmpnt_type ON cmpnt_type
(parent_cmpnt_type_id   ASC);

CREATE TABLE cmpnt_type_owners
(
    cmpnt_type_id        INTEGER NOT NULL ,
    owner                VARCHAR2(20) NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_type_owners IS 'Identifies users or groups who may create instances of a type of cmpnt';

COMMENT ON COLUMN cmpnt_type_owners.cmpnt_type_id IS 'The unique database handle for the component type';

COMMENT ON COLUMN cmpnt_type_owners.owner IS 'The unix username or group name.  By convention group names are prefixed with $ to distinquish them from usernames.';

ALTER TABLE cmpnt_type_owners
    ADD CONSTRAINT  XPKcmpnt_type_owners PRIMARY KEY (cmpnt_type_id,owner);

CREATE TABLE cmpnt_type_prop
(
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    cmpnt_type_id        INTEGER NOT NULL ,
    name                 VARCHAR2(255) NOT NULL ,
    type                 VARCHAR2(20) NOT NULL ,
    units                VARCHAR2(20) NULL ,
    description          VARCHAR2(4000) NULL ,
    live_edit            SMALLINT DEFAULT  0  NULL ,
    category_id          INTEGER NULL ,
    multipass            SMALLINT DEFAULT  0  NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_type_prop IS 'This table identifies the properties associated with each type of component. When a new component is added to the cmpnt table, the properties specific to its component type (specified in this cmpnt_type_prop table) will be stored in the cmpnt_prop table.
Because the cmpnt_prop table and its subtables (cmpnt_prop_float, cmpnt_prop_string, etc.) store values for any component, it is up to the application that stores information there to enforce proper data type constraints. The application can do so by referencing the value_type and value_type_limit columns of the cmpnt_type_prop table. The table below lists the possible values and their meaning. 
value_type   value_type_limit    Example
int                       range                     (1:3]
bits                        
float                     range                     (1:3]
string                    regex                     ^MQA.+$
text                           regex 
uri                              regex
list                      regex list     
date                      Oracle date    
fk                    Type name     Magnet
bool                      0/1   
data                           N/A';

COMMENT ON COLUMN cmpnt_type_prop.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_type_prop.cmpnt_type_id IS 'Identifies the cmpnt_type to which the property is applicable. see cmpnt_type table';

COMMENT ON COLUMN cmpnt_type_prop.name IS 'A name for the component property. Ex: Length, Slot Num, Wire Gauge, Channel, etc. The name must be unique for each cmpnt_type_id';

COMMENT ON COLUMN cmpnt_type_prop.type IS 'Specifies the valid data type for value, such as float, string, blob, etc.  (please see CED API documentation)';

COMMENT ON COLUMN cmpnt_type_prop.units IS 'Documents the units of measure for value';

COMMENT ON COLUMN cmpnt_type_prop.description IS 'For description and comments regarding the current property';

COMMENT ON COLUMN cmpnt_type_prop.live_edit IS 'Whether or not values of this property may be updated in LIVE workspace';

COMMENT ON COLUMN cmpnt_type_prop.category_id IS 'Primary key of the prop_cats table.  Null values are used for "System" properties such as SegMask that generally are not displayed to users.';

COMMENT ON COLUMN cmpnt_type_prop.multipass IS 'Indicates whether dim1 should be interpreted as pass number for multipass elements.  0 (the default means interpret dim1 as generic array index) and 1 means interpret it as pass number.';

ALTER TABLE cmpnt_type_prop
    ADD CONSTRAINT  XPKcmpnt_type_prop PRIMARY KEY (cmpnt_type_prop_id);

CREATE UNIQUE INDEX XAK1cmpnt_type_prop_name ON cmpnt_type_prop
(cmpnt_type_id   ASC,name   ASC);

ALTER TABLE cmpnt_type_prop
ADD CONSTRAINT  XAK1cmpnt_type_prop_name UNIQUE (cmpnt_type_id,name)  ENABLE;

ALTER TABLE cmpnt_type_prop
    MODIFY type CONSTRAINT  Valid_Type CHECK (type IN ('string', 'int', 'float', 'list', 'bool', 'binary', 'date', 'uri', 'fk', 'data', 'bits', 'text', 'mixed'));

ALTER TABLE cmpnt_type_prop
    MODIFY multipass CONSTRAINT  Valid_Boolean_1666130632 CHECK (multipass IN (0, 1));

CREATE INDEX XIF1cmpnt_type_prop ON cmpnt_type_prop
(cmpnt_type_id   ASC);

CREATE INDEX XIF2cmpnt_type_prop ON cmpnt_type_prop
(category_id   ASC);

CREATE TABLE cmpnt_type_prop_cats
(
    category_id          INTEGER NOT NULL ,
    category             VARCHAR2(40) NOT NULL ,
    ordering             INTEGER DEFAULT  100  NOT NULL ,
    set_id               INTEGER NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_type_prop_cats IS 'Definies categories that can be used to group properties.  For instance, x, y, z coordinate properties could all be associated with a  "Survey" category.  Tools can then output these related properties clustered together.';

COMMENT ON COLUMN cmpnt_type_prop_cats.category_id IS 'Primary key of the prop_cats table';

COMMENT ON COLUMN cmpnt_type_prop_cats.category IS 'The string or name that identifies the category';

COMMENT ON COLUMN cmpnt_type_prop_cats.ordering IS 'Provides relative ordering of sets.  Lower numbers will be displayed before higher numbers.';

COMMENT ON COLUMN cmpnt_type_prop_cats.set_id IS 'Primary key';

ALTER TABLE cmpnt_type_prop_cats
    ADD CONSTRAINT  XPKprop_cats PRIMARY KEY (category_id);

CREATE UNIQUE INDEX XAK1prop_cats ON cmpnt_type_prop_cats
(category   ASC,set_id   ASC);

ALTER TABLE cmpnt_type_prop_cats
ADD CONSTRAINT  XAK1prop_cats UNIQUE (category,set_id);

CREATE INDEX XIF1prop_cats ON cmpnt_type_prop_cats
(set_id   ASC);

CREATE TABLE cmpnt_type_prop_def
(
    cmpnt_type_id        INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    value_default        VARCHAR2(4000) NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_type_prop_def IS 'This table allows default values to be type-specific. A component that inherits a property from a parent type may have its own default value.';

COMMENT ON COLUMN cmpnt_type_prop_def.cmpnt_type_id IS 'The unique database handle for the component type';

COMMENT ON COLUMN cmpnt_type_prop_def.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_type_prop_def.value_default IS 'A default value for whenever a component of the type is instantiated';

ALTER TABLE cmpnt_type_prop_def
    ADD CONSTRAINT  XPKcmpnt_type_prop_default PRIMARY KEY (cmpnt_type_id,cmpnt_type_prop_id);

CREATE INDEX XIF1cmpnt_type_prop_default ON cmpnt_type_prop_def
(cmpnt_type_id   ASC);

CREATE INDEX XIF2cmpnt_type_prop_default ON cmpnt_type_prop_def
(cmpnt_type_prop_id   ASC);

CREATE TABLE cmpnt_type_prop_dim
(
    cmpnt_type_id        INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    dim1_max             INTEGER DEFAULT  1  NOT NULL ,
    dim2_max             INTEGER DEFAULT  1  NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_type_prop_dim IS 'This table allows property array dimensions to be type-specific. A component that inherits a property from a parent type may have its own dimension.  An example would ConsoleServers where the SerialPorts property may permit 4 values for one model and 8, 16, 32, etc. for another.';

COMMENT ON COLUMN cmpnt_type_prop_dim.cmpnt_type_id IS 'The unique database handle for the component type';

COMMENT ON COLUMN cmpnt_type_prop_dim.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_type_prop_dim.dim1_max IS 'Permits the property to be a multi-value 1-dimensional vector type. Interpretation is:  
0: unbounded packed array of values
1 : single value property (default)
N: static array of N values
';

COMMENT ON COLUMN cmpnt_type_prop_dim.dim2_max IS 'Permits the property to be a multi-value 1-dimensional vector type. Interpretation is:  
0: unbounded packed array of values
1 : single value property (default)
N: static array of N values';

ALTER TABLE cmpnt_type_prop_dim
    ADD CONSTRAINT  XPKcmpnt_type_prop_dim PRIMARY KEY (cmpnt_type_id,cmpnt_type_prop_id);

ALTER TABLE cmpnt_type_prop_dim
    MODIFY dim1_max CONSTRAINT  Pos_Int_722850753 CHECK (dim1_max >= 0);

ALTER TABLE cmpnt_type_prop_dim
    MODIFY dim2_max CONSTRAINT  Pos_Int_739627969 CHECK (dim2_max >= 0);

CREATE INDEX XIF1cmpnt_type_prop_dim ON cmpnt_type_prop_dim
(cmpnt_type_id   ASC);

CREATE INDEX XIF2cmpnt_type_prop_dim ON cmpnt_type_prop_dim
(cmpnt_type_prop_id   ASC);

CREATE TABLE cmpnt_type_prop_dom
(
    cmpnt_type_id        INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    domain               VARCHAR2(1024) NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_type_prop_dom IS 'This table allows property domain limits to be type-specific. A component that inherits a property from a parent type may have its own domain restrictions.';

COMMENT ON COLUMN cmpnt_type_prop_dom.cmpnt_type_id IS 'The unique database handle for the component type';

COMMENT ON COLUMN cmpnt_type_prop_dom.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_type_prop_dom.domain IS 'Specifies limits for value_type (see CED API documentation). Note that 255 chars is max regex length for Oracle regexp_* functions.';

ALTER TABLE cmpnt_type_prop_dom
    ADD CONSTRAINT  XPKcmpnt_type_prop_dom PRIMARY KEY (cmpnt_type_id,cmpnt_type_prop_id);

CREATE INDEX XIF1cmpnt_type_prop_dom ON cmpnt_type_prop_dom
(cmpnt_type_id   ASC);

CREATE INDEX XIF2cmpnt_type_prop_dom ON cmpnt_type_prop_dom
(cmpnt_type_prop_id   ASC);

CREATE TABLE cmpnt_type_prop_mix
(
    cmpnt_type_id        INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    indx                 INTEGER NOT NULL ,
    type                 VARCHAR2(20) NULL ,
    label                VARCHAR2(24) NULL ,
    domain               VARCHAR2(1024) NULL 
);

COMMENT ON TABLE cmpnt_type_prop_mix IS 'Stores attributes necessary to define vectors with mixed property types.  In other words 1D or 2D vectors where each column can be of a different primitive type.';

COMMENT ON COLUMN cmpnt_type_prop_mix.cmpnt_type_id IS 'The unique database handle for the component type';

COMMENT ON COLUMN cmpnt_type_prop_mix.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_type_prop_mix.indx IS 'The dimension index to which the type and domain columns apply.   The indx value of 0 would hold the default value for any vector indeces (1..X) that are not explicitly defined as something else.';

COMMENT ON COLUMN cmpnt_type_prop_mix.type IS 'The type permitted (float, string, etc.) at the dimension specified in the current row indx column.';

COMMENT ON COLUMN cmpnt_type_prop_mix.label IS 'An optional label which can identify the purpose of the value at the specified dimension  in the current row indx column.';

COMMENT ON COLUMN cmpnt_type_prop_mix.domain IS 'The domain restriction to be applied to values at the dimension specified in the current row indx column.';

ALTER TABLE cmpnt_type_prop_mix
    ADD CONSTRAINT  XPKcmpnt_type_prop_mix PRIMARY KEY (cmpnt_type_id,cmpnt_type_prop_id,indx);

CREATE INDEX XIF1cmpnt_type_prop_mix ON cmpnt_type_prop_mix
(cmpnt_type_id   ASC);

CREATE INDEX XIF2cmpnt_type_prop_mix ON cmpnt_type_prop_mix
(cmpnt_type_prop_id   ASC);

CREATE TABLE cmpnt_type_prop_owners
(
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    owner                VARCHAR2(20) NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_type_prop_owners IS 'Identifies users or groups who may set/modify the value of specific properties across cmpnt instances.';

COMMENT ON COLUMN cmpnt_type_prop_owners.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_type_prop_owners.owner IS 'The unix username or group name.  By convention group names are prefixed with $ to distinquish them from usernames.';

ALTER TABLE cmpnt_type_prop_owners
    ADD CONSTRAINT  XPKcmpnt_type_prop_owners PRIMARY KEY (cmpnt_type_prop_id,owner);

CREATE TABLE cmpnt_type_prop_req
(
    cmpnt_type_id        INTEGER DEFAULT  0  NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    required             SMALLINT DEFAULT  1  NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE cmpnt_type_prop_req IS 'This table allows sub-types to override whether an inherited property is required or not.';

COMMENT ON COLUMN cmpnt_type_prop_req.cmpnt_type_id IS 'The unique database handle for the component type';

COMMENT ON COLUMN cmpnt_type_prop_req.cmpnt_type_prop_id IS 'The unique database handle for the component type property';

COMMENT ON COLUMN cmpnt_type_prop_req.required IS 'Whether or not a value for this property is required when a component of the type is instantiated';

ALTER TABLE cmpnt_type_prop_req
    ADD CONSTRAINT  XPKcmpnt_type_prop_req PRIMARY KEY (cmpnt_type_id,cmpnt_type_prop_id);

ALTER TABLE cmpnt_type_prop_req
    MODIFY required CONSTRAINT  Valid_Boolean_prop_req CHECK (required IN (0, 1));

CREATE INDEX XIF1cmpnt_type_prop_req ON cmpnt_type_prop_req
(cmpnt_type_id   ASC);

CREATE INDEX XIF2cmpnt_type_prop_req ON cmpnt_type_prop_req
(cmpnt_type_prop_id   ASC);

CREATE TABLE hist_cmpnt
(
    event_id             INTEGER NOT NULL ,
    owner                VARCHAR2(30) NOT NULL ,
    workspace            VARCHAR2(30) NOT NULL ,
    table_name           VARCHAR2(30) NOT NULL ,
    cmpnt_id             INTEGER NOT NULL ,
    action_flag          CHAR(1) NOT NULL ,
    event_date           DATE NOT NULL ,
    old_name             VARCHAR2(4000) NULL ,
    new_name             VARCHAR2(4000) NULL ,
    old_cmpnt_type_id    INTEGER NULL ,
    new_cmpnt_type_id    INTEGER NULL ,
    ack                  SMALLINT DEFAULT  0  NOT NULL 
);

COMMENT ON TABLE hist_cmpnt IS 'Tracks the history of inserts, updates, and deletes to the cmpnt table';

COMMENT ON COLUMN hist_cmpnt.event_id IS 'Key that groups related history rows together as part of the same logical transaction';

COMMENT ON COLUMN hist_cmpnt.owner IS 'The schema to which the history belongs';

COMMENT ON COLUMN hist_cmpnt.workspace IS 'The workspace in which the history was generated';

COMMENT ON COLUMN hist_cmpnt.table_name IS 'The table that was the source of the history';

COMMENT ON COLUMN hist_cmpnt.cmpnt_id IS 'Key of the element that was updated';

COMMENT ON COLUMN hist_cmpnt.action_flag IS 'The type of event that triggered the current row.  I = Insert, U=Update, D=Delete';

COMMENT ON COLUMN hist_cmpnt.event_date IS 'Timestamp the row was inserted into this table';

COMMENT ON COLUMN hist_cmpnt.old_name IS 'Name of the element prior to event';

COMMENT ON COLUMN hist_cmpnt.new_name IS 'Name of the element after event';

COMMENT ON COLUMN hist_cmpnt.old_cmpnt_type_id IS 'Type of the element prior to event';

COMMENT ON COLUMN hist_cmpnt.new_cmpnt_type_id IS 'Type of the element after event';

COMMENT ON COLUMN hist_cmpnt.ack IS 'Whether the row has been acknowledged by the ced_notify system.  0 = needs acknowledgement.  1 = acknowledged or does not need acknowledgement.';

ALTER TABLE hist_cmpnt
    MODIFY action_flag CONSTRAINT  IUD_1901753180 CHECK (action_flag IN ('I', 'U', 'D'));

ALTER TABLE hist_cmpnt
    MODIFY ack CONSTRAINT  Valid_Boolean_1868356569 CHECK (ack IN (0, 1));

CREATE TABLE hist_cmpnt_prop
(
    event_id             INTEGER NOT NULL ,
    owner                VARCHAR2(30) NOT NULL ,
    workspace            VARCHAR2(30) NOT NULL ,
    table_name           VARCHAR2(30) NOT NULL ,
    cmpnt_id             INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    action_flag          CHAR(1) NOT NULL ,
    event_date           DATE NOT NULL ,
    old_comments         VARCHAR2(4000) NULL ,
    new_comments         VARCHAR2(4000) NULL ,
    old_set_by           VARCHAR2(20) NULL ,
    new_set_by           VARCHAR2(20) NULL ,
    old_modify_date      TIMESTAMP NULL ,
    new_modify_date      TIMESTAMP NULL ,
    ack                  SMALLINT DEFAULT  0  NOT NULL 
);

COMMENT ON TABLE hist_cmpnt_prop IS 'Tracks the history of inserts, updates, and deletes to the cmpnt_prop table';

COMMENT ON COLUMN hist_cmpnt_prop.event_id IS 'Key that groups related history rows together as part of the same logical transaction';

COMMENT ON COLUMN hist_cmpnt_prop.owner IS 'The schema to which the history belongs';

COMMENT ON COLUMN hist_cmpnt_prop.workspace IS 'The workspace in which the history was generated';

COMMENT ON COLUMN hist_cmpnt_prop.table_name IS 'The table that was the source of the history';

COMMENT ON COLUMN hist_cmpnt_prop.cmpnt_id IS 'Key of the element that was updated';

COMMENT ON COLUMN hist_cmpnt_prop.cmpnt_type_prop_id IS 'Key of the property that was altered';

COMMENT ON COLUMN hist_cmpnt_prop.action_flag IS 'The type of event that triggered the current row.  I = Insert, U=Update, D=Delete';

COMMENT ON COLUMN hist_cmpnt_prop.event_date IS 'Timestamp the row was inserted into this table';

COMMENT ON COLUMN hist_cmpnt_prop.old_comments IS 'Comments prior to event';

COMMENT ON COLUMN hist_cmpnt_prop.new_comments IS 'Comments after event';

COMMENT ON COLUMN hist_cmpnt_prop.old_set_by IS 'contents of set_by prior to event';

COMMENT ON COLUMN hist_cmpnt_prop.new_set_by IS 'contents of set_by prior after event';

COMMENT ON COLUMN hist_cmpnt_prop.old_modify_date IS 'prior modify_date';

COMMENT ON COLUMN hist_cmpnt_prop.new_modify_date IS 'current modify_date';

COMMENT ON COLUMN hist_cmpnt_prop.ack IS 'Whether the row has been acknowledged by the ced_notify system.  0 = needs acknowledgement.  1 = acknowledged or does not need acknowledgement.';

ALTER TABLE hist_cmpnt_prop
    MODIFY action_flag CONSTRAINT  IUD_339089377 CHECK (action_flag IN ('I', 'U', 'D'));

ALTER TABLE hist_cmpnt_prop
    MODIFY ack CONSTRAINT  Valid_Boolean_467642808 CHECK (ack IN (0, 1));

CREATE TABLE hist_cmpnt_prop_val
(
    event_id             INTEGER NOT NULL ,
    owner                VARCHAR2(30) NOT NULL ,
    workspace            VARCHAR2(30) NOT NULL ,
    table_name           VARCHAR2(30) NOT NULL ,
    cmpnt_id             INTEGER NOT NULL ,
    cmpnt_type_prop_id   INTEGER NOT NULL ,
    action_flag          CHAR(1) NOT NULL ,
    event_date           DATE NOT NULL ,
    old_value            VARCHAR2(4000) NULL ,
    new_value            VARCHAR2(4000) NULL ,
    dim1                 INTEGER NULL ,
    dim2                 INTEGER NULL ,
    ack                  SMALLINT DEFAULT  0  NOT NULL 
);

COMMENT ON TABLE hist_cmpnt_prop_val IS 'Tracks the history of inserts, updates, and deletes to the cmpnt_prop_* tables such as cmpnt_prop_string, cmpnt_prop_float, etc.';

COMMENT ON COLUMN hist_cmpnt_prop_val.event_id IS 'Key that groups related history rows together as part of the same logical transaction';

COMMENT ON COLUMN hist_cmpnt_prop_val.owner IS 'The schema to which the history belongs';

COMMENT ON COLUMN hist_cmpnt_prop_val.workspace IS 'The workspace in which the history was generated';

COMMENT ON COLUMN hist_cmpnt_prop_val.table_name IS 'The table that was the source of the history';

COMMENT ON COLUMN hist_cmpnt_prop_val.cmpnt_id IS 'Key of the element that was updated';

COMMENT ON COLUMN hist_cmpnt_prop_val.cmpnt_type_prop_id IS 'key of the property that was altered';

COMMENT ON COLUMN hist_cmpnt_prop_val.action_flag IS 'The type of event that triggered the current row.  I = Insert, U=Update, D=Delete';

COMMENT ON COLUMN hist_cmpnt_prop_val.event_date IS 'Timestamp the row was inserted into this table';

COMMENT ON COLUMN hist_cmpnt_prop_val.old_value IS 'String representation of the value prior to change.  Non-character data types are cast to strings in the same manner as the v_cmpnt_prop_val view does.';

COMMENT ON COLUMN hist_cmpnt_prop_val.new_value IS 'String representation of the value after change.  Non-character data types are cast to strings in the same manner as the v_cmpnt_prop_val view does.';

COMMENT ON COLUMN hist_cmpnt_prop_val.dim1 IS 'vector dimension index 1 of the altered property';

COMMENT ON COLUMN hist_cmpnt_prop_val.dim2 IS 'vector dimension index 2 of the altered property';

COMMENT ON COLUMN hist_cmpnt_prop_val.ack IS 'Whether the row has been acknowledged by the ced_notify system.  0 = needs acknowledgement.  1 = acknowledged or does not need acknowledgement.';

ALTER TABLE hist_cmpnt_prop_val
    MODIFY action_flag CONSTRAINT  IUD_1295402902 CHECK (action_flag IN ('I', 'U', 'D'));

ALTER TABLE hist_cmpnt_prop_val
    MODIFY ack CONSTRAINT  Valid_Boolean_1133950901 CHECK (ack IN (0, 1));

CREATE TABLE merge_log
(
    logdate              DATE NULL ,
    username             VARCHAR2(12) NULL ,
    message              VARCHAR2(512) NULL 
);

COMMENT ON TABLE merge_log IS 'This table is used to log a history of merge to OPS activity';

COMMENT ON COLUMN merge_log.logdate IS 'Timestamp of the entry';

COMMENT ON COLUMN merge_log.username IS 'The username of person making the entry';

COMMENT ON COLUMN merge_log.message IS 'The text to be logged as provided by the user';

CREATE INDEX IDX1merge_log ON merge_log
(logdate   ASC);

CREATE TABLE segments
(
    mask                 INTEGER NULL ,
    zone_id              INTEGER NOT NULL ,
    end_cmpnt            INTEGER NULL ,
    start_cmpnt          INTEGER NULL ,
    start_pass           SMALLINT NULL ,
    end_pass             SMALLINT NULL ,
    segment_id           INTEGER NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE segments IS 'Identifies beamline elements that share a common region.';

COMMENT ON COLUMN segments.mask IS 'A 64-bit bitfield specific to the segment';

COMMENT ON COLUMN segments.zone_id IS 'Zone to which the segment belongs';

COMMENT ON COLUMN segments.end_cmpnt IS 'Identifies the component at which the segment ends (see cmpnt table)';

COMMENT ON COLUMN segments.start_cmpnt IS 'Identifies the component at which the segment begins (see cmpnt table)';

COMMENT ON COLUMN segments.start_pass IS 'Identifies the pass of start_cmpnt';

COMMENT ON COLUMN segments.end_pass IS 'Identifies the pass of end_cmpnt';

COMMENT ON COLUMN segments.segment_id IS 'Unique identifier';

ALTER TABLE segments
    ADD CONSTRAINT  XPKSegments PRIMARY KEY (segment_id);

ALTER TABLE segments
    MODIFY start_pass CONSTRAINT  Valid_Pass_Name_876435125 CHECK (start_pass IN (0, 1, 2, 3, 4, 5, 6));

ALTER TABLE segments
    MODIFY end_pass CONSTRAINT  Valid_Pass_Name_851557068 CHECK (end_pass IN (0, 1, 2, 3, 4, 5, 6));

CREATE INDEX XIF1zones ON segments
(start_cmpnt   ASC);

CREATE INDEX XIF2zones ON segments
(zone_id   ASC);

CREATE INDEX XIF3zones ON segments
(end_cmpnt   ASC);

CREATE TABLE usage_log
(
    logdate              DATE NULL ,
    hostname             VARCHAR2(20) NULL ,
    username             VARCHAR2(12) NULL ,
    app                  VARCHAR2(512) NULL ,
    wkspc                VARCHAR2(30) NULL ,
    lib                  VARCHAR2(20) NULL 
);

COMMENT ON TABLE usage_log IS 'Log table to track programs, users, client hosts that access CED';

COMMENT ON COLUMN usage_log.logdate IS 'timestamp';

COMMENT ON COLUMN usage_log.hostname IS 'host where client program executed';

COMMENT ON COLUMN usage_log.username IS 'the username executing the client';

COMMENT ON COLUMN usage_log.app IS 'the program that was used';

COMMENT ON COLUMN usage_log.wkspc IS 'the workspace that was accessed';

COMMENT ON COLUMN usage_log.lib IS 'Identifies the library/API version used by the application.  Potentially useful to track down applications using old versions of API.';

CREATE TABLE web_auth
(
    token                VARCHAR2(64) NOT NULL ,
    username             VARCHAR2(20) NULL ,
    issued               DATE NULL 
);

COMMENT ON TABLE web_auth IS 'Used to authenticate web users to the CED API';

COMMENT ON COLUMN web_auth.token IS 'Unique token (typically session key) generated by web service.  It can be used in lieu of host credentials for CED authentication.';

COMMENT ON COLUMN web_auth.username IS 'The username associated with token';

COMMENT ON COLUMN web_auth.issued IS 'Time the token was issued.  Tokens with an issued date more than 2 hours past are no longer valid.';

ALTER TABLE web_auth
    ADD CONSTRAINT  XPKweb_auth PRIMARY KEY (token);

CREATE TABLE workspace_info
(
    workspace            VARCHAR2(255) NOT NULL ,
    inventory_lastmod    DATE NULL ,
    no_merge             INTEGER DEFAULT  0  NULL ,
    no_delete            INTEGER DEFAULT  0  NULL 
);

COMMENT ON TABLE workspace_info IS 'This table stores metadata about the workspaces';

COMMENT ON COLUMN workspace_info.workspace IS 'Name of workspace (LIVE, Admin, STAGE, etc.)';

COMMENT ON COLUMN workspace_info.inventory_lastmod IS 'The date in this column indicates the most recent date and time that the contents of any inventory tables (cmpnt_prop and dependents) were updated.  It is maintained via trigger on cmpnt_prop and is used to determine if/when the mv_cmpnt_prop_val_live materialized view needs refreshing.';

COMMENT ON COLUMN workspace_info.no_merge IS 'True (value=1) indicates the workspaces should not be merged in its entirety.';

COMMENT ON COLUMN workspace_info.no_delete IS 'True (value=1) indicates the workspaces should not be deleted';

ALTER TABLE workspace_info
    ADD CONSTRAINT  XPKworkspace_info PRIMARY KEY (workspace);

ALTER TABLE workspace_info
    MODIFY no_merge CONSTRAINT  Valid_Boolean_1284619177 CHECK (no_merge IN (0, 1));

ALTER TABLE workspace_info
    MODIFY no_delete CONSTRAINT  Valid_Boolean_1466191695 CHECK (no_delete IN (0, 1));

CREATE TABLE zone_links
(
    zone_id              INTEGER NOT NULL ,
    parent_zone_id       INTEGER NOT NULL ,
    zone_links_id        INTEGER NOT NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE zone_links IS 'Permits hierarchical zones';

COMMENT ON COLUMN zone_links.zone_id IS 'Uniquely identifies the zone';

COMMENT ON COLUMN zone_links.parent_zone_id IS 'Points to the parent zone';

COMMENT ON COLUMN zone_links.zone_links_id IS 'Creates an ordered hiearchy of zones.';

ALTER TABLE zone_links
    ADD CONSTRAINT  XPKzone_links PRIMARY KEY (zone_links_id);

CREATE INDEX XIF1zone_links ON zone_links
(zone_id   ASC);

CREATE INDEX XIF2zone_links ON zone_links
(parent_zone_id   ASC);

CREATE TABLE zones
(
    name                 VARCHAR2(20) NOT NULL ,
    zone_id              INTEGER NOT NULL ,
    is_multi             SMALLINT DEFAULT  0  NULL ,
    description          VARCHAR2(255) NULL ,
    contiguous           SMALLINT DEFAULT  1  NULL 
)
    ROWDEPENDENCIES;

COMMENT ON TABLE zones IS 'Used to group segments with a friendly recognizable name (example ARC1)';

COMMENT ON COLUMN zones.name IS 'The name of the zone';

COMMENT ON COLUMN zones.zone_id IS 'Uniquely identifies the zone';

COMMENT ON COLUMN zones.is_multi IS 'Whether or not the zone spans multiple recirculations';

COMMENT ON COLUMN zones.description IS 'Explanatory text';

COMMENT ON COLUMN zones.contiguous IS 'Specifies whether the segments and subzones should be considered contiguous.  Set it to 0 for disjoint zones.';

ALTER TABLE zones
    ADD CONSTRAINT  XPKzones PRIMARY KEY (zone_id);

CREATE UNIQUE INDEX XAK1zones ON zones
(name   ASC);

ALTER TABLE zones
ADD CONSTRAINT  XAK1zones UNIQUE (name);

ALTER TABLE zones
    MODIFY is_multi CONSTRAINT  Valid_Boolean_2068709094 CHECK (is_multi IN (0, 1));

ALTER TABLE zones
    MODIFY contiguous CONSTRAINT  Valid_Boolean_20581663 CHECK (contiguous IN (0, 1));

ALTER TABLE cmpnt
    ADD (CONSTRAINT FK_CMPNT_CMPNT_TYPE_ID FOREIGN KEY (cmpnt_type_id) REFERENCES cmpnt_type (cmpnt_type_id));

ALTER TABLE cmpnt_owners
    ADD (CONSTRAINT FK_CMPNT_OWNERS_CMPNT_ID FOREIGN KEY (cmpnt_id) REFERENCES cmpnt (cmpnt_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_prop
    ADD (CONSTRAINT FK_CMPNT_PROP_CMPNT_ID FOREIGN KEY (cmpnt_id) REFERENCES cmpnt (cmpnt_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_prop
    ADD (CONSTRAINT FK_CMPNT_PROP_PROP_TYPE_ID FOREIGN KEY (cmpnt_type_prop_id) REFERENCES cmpnt_type_prop (cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_prop_blob
    ADD (CONSTRAINT FK_CMPNT_PROP_BLOB FOREIGN KEY (cmpnt_id, cmpnt_type_prop_id) REFERENCES cmpnt_prop (cmpnt_id, cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_prop_bool
    ADD (CONSTRAINT FK_CMPNT_PROP_BOOL FOREIGN KEY (cmpnt_id, cmpnt_type_prop_id) REFERENCES cmpnt_prop (cmpnt_id, cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_prop_date
    ADD (CONSTRAINT FK_CMPNT_PROP_DATE FOREIGN KEY (cmpnt_id, cmpnt_type_prop_id) REFERENCES cmpnt_prop (cmpnt_id, cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_prop_fk_cmpnt
    ADD (CONSTRAINT FK_CMPNT_PROP_FK_ID1 FOREIGN KEY (cmpnt_id, cmpnt_type_prop_id) REFERENCES cmpnt_prop (cmpnt_id, cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_prop_fk_cmpnt
    ADD (CONSTRAINT FK_CMPNT_PROP_FK_ID2 FOREIGN KEY (value) REFERENCES cmpnt (cmpnt_id));

ALTER TABLE cmpnt_prop_float
    ADD (CONSTRAINT FK_CMPNT_PROP_FLOAT FOREIGN KEY (cmpnt_id, cmpnt_type_prop_id) REFERENCES cmpnt_prop (cmpnt_id, cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_prop_integer
    ADD (CONSTRAINT FK_CMPNT_PROP_INTEGER FOREIGN KEY (cmpnt_id, cmpnt_type_prop_id) REFERENCES cmpnt_prop (cmpnt_id, cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_prop_string
    ADD (CONSTRAINT FK_CMPNT_PROP_STRING FOREIGN KEY (cmpnt_id, cmpnt_type_prop_id) REFERENCES cmpnt_prop (cmpnt_id, cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type
    ADD (CONSTRAINT FK_CMPNT_TYPE_PARENT_ID FOREIGN KEY (parent_cmpnt_type_id) REFERENCES cmpnt_type (cmpnt_type_id));

ALTER TABLE cmpnt_type_owners
    ADD (CONSTRAINT FK_CMPNT_TYPE_OWNERS_ID FOREIGN KEY (cmpnt_type_id) REFERENCES cmpnt_type (cmpnt_type_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop
    ADD (CONSTRAINT FK_CMPNT_TYPE_PROP_TYPE_ID FOREIGN KEY (cmpnt_type_id) REFERENCES cmpnt_type (cmpnt_type_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop
    ADD (CONSTRAINT FK_TYPE_PROP_CAT_ID FOREIGN KEY (category_id) REFERENCES cmpnt_type_prop_cats (category_id));

ALTER TABLE cmpnt_type_prop_cats
    ADD (CONSTRAINT FK_PROP_CAT_SET_ID FOREIGN KEY (set_id) REFERENCES category_sets (set_id) ON DELETE SET NULL);

ALTER TABLE cmpnt_type_prop_def
    ADD (CONSTRAINT FK_PROP_DEF_TYPE_ID FOREIGN KEY (cmpnt_type_id) REFERENCES cmpnt_type (cmpnt_type_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop_def
    ADD (CONSTRAINT FK_PROP_DEF_PROP_ID FOREIGN KEY (cmpnt_type_prop_id) REFERENCES cmpnt_type_prop (cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop_dim
    ADD (CONSTRAINT FK_PROP_DIM_TYPE_ID FOREIGN KEY (cmpnt_type_id) REFERENCES cmpnt_type (cmpnt_type_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop_dim
    ADD (CONSTRAINT FK_PROP_DIM_PROP_ID FOREIGN KEY (cmpnt_type_prop_id) REFERENCES cmpnt_type_prop (cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop_dom
    ADD (CONSTRAINT FK_PROP_DOM_TYPE_ID FOREIGN KEY (cmpnt_type_id) REFERENCES cmpnt_type (cmpnt_type_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop_dom
    ADD (CONSTRAINT FK_PROP_DOM_PROP_ID FOREIGN KEY (cmpnt_type_prop_id) REFERENCES cmpnt_type_prop (cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop_mix
    ADD (CONSTRAINT FK_CMPNT_TYPE_PROP_MIX_TYPE_ID FOREIGN KEY (cmpnt_type_id) REFERENCES cmpnt_type (cmpnt_type_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop_mix
    ADD (CONSTRAINT FK_CMPNT_TYPE_PROP_MIX_PROP_ID FOREIGN KEY (cmpnt_type_prop_id) REFERENCES cmpnt_type_prop (cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop_owners
    ADD (CONSTRAINT FK_CMPNT_TYPE_OWNERS_PROP_ID FOREIGN KEY (cmpnt_type_prop_id) REFERENCES cmpnt_type_prop (cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop_req
    ADD (CONSTRAINT FK_PROP_REQ_TYPE_ID FOREIGN KEY (cmpnt_type_id) REFERENCES cmpnt_type (cmpnt_type_id) ON DELETE CASCADE);

ALTER TABLE cmpnt_type_prop_req
    ADD (CONSTRAINT FK_PROP_REQ_PROP_ID FOREIGN KEY (cmpnt_type_prop_id) REFERENCES cmpnt_type_prop (cmpnt_type_prop_id) ON DELETE CASCADE);

ALTER TABLE segments
    ADD (CONSTRAINT FK_SEGMENTS_START_CMPNT FOREIGN KEY (start_cmpnt) REFERENCES cmpnt (cmpnt_id));

ALTER TABLE segments
    ADD (CONSTRAINT FK_SEGMENTS_ZONE_ID FOREIGN KEY (zone_id) REFERENCES zones (zone_id) ON DELETE CASCADE);

ALTER TABLE segments
    ADD (CONSTRAINT FK_SEGMENTS_END_CMPNT FOREIGN KEY (end_cmpnt) REFERENCES cmpnt (cmpnt_id));

ALTER TABLE zone_links
    ADD (CONSTRAINT FK_ZONE_ZONE_ID1 FOREIGN KEY (zone_id) REFERENCES zones (zone_id) ON DELETE CASCADE);

ALTER TABLE zone_links
    ADD (CONSTRAINT FK_ZONE_ZONE_ID2 FOREIGN KEY (parent_zone_id) REFERENCES zones (zone_id) ON DELETE CASCADE);

/* A little tweaking of caching */

/*
alter table zones storage (buffer_pool keep);
alter table segments storage (buffer_pool keep);
alter table cmpnt_type storage (buffer_pool keep);

alter index XPKcmpnt_type rebuild storage (buffer_pool keep);
alter index XAK1cmpnt_type_Up rebuild storage (buffer_pool keep);

alter table cmpnt_type_prop storage (buffer_pool keep);
alter index XPKcmpnt_type_prop rebuild storage (buffer_pool keep);
alter index XAK1cmpnt_type_prop_name rebuild storage (buffer_pool keep);

alter index XAK1cmpnt_name_Up rebuild storage (buffer_pool keep);
*/





/* ERWin seems incapable of making function-based unique indexes, so we have to add them ourselves as a post script*/


-- We don't want repetitions of cmpnt, zone, or type that differ only by case
CREATE UNIQUE INDEX XAK1cmpnt_name_Up ON cmpnt (upper(name)  ASC);
CREATE UNIQUE INDEX XAK1cmpnt_type_Up ON cmpnt_type (upper(name)  ASC);
CREATE UNIQUE INDEX XAK1zone_name_Up ON zones (upper(name)  ASC);




-- ERWin can't handle creating views with UNION.  We let ERWin draw the view, but we have to create
-- it here manually ourselves 

create or replace view v_cmpnt_prop_val
(cmpnt_id, cmpnt_type_prop_id, dim1, dim2, value)
as
    select  k.cmpnt_id, k.cmpnt_type_prop_id, k.dim1, k.dim2, n.name
    from cmpnt_prop_fk_cmpnt k, cmpnt n
        where n.cmpnt_id = k.value
union all
    select b.cmpnt_id, b.cmpnt_type_prop_id, b.dim1, b.dim2, to_char(b.value)
    from cmpnt_prop_bool b
union all
    select  x.cmpnt_id, x.cmpnt_type_prop_id, x.dim1, x.dim2, 'Data ( '||x.mime_type||' )'
    from cmpnt_prop c, cmpnt_prop_blob x
        where c.cmpnt_id = x.cmpnt_id and c.cmpnt_type_prop_id = x.cmpnt_type_prop_id
union all
    select  i.cmpnt_id, i.cmpnt_type_prop_id, i.dim1, i.dim2, to_char(i.value)
    from cmpnt_prop_integer i
union all
    select  f.cmpnt_id, f.cmpnt_type_prop_id, f.dim1, f.dim2,  case
                                when f.value = 0 then '0'
                                when abs(f.value) > 99999 then to_char(f.value, 'TMe')
                                when abs(f.value) < 0.00001 then to_char(f.value, 'TMe')
                                else to_char(f.value, 'TM9')
                            end
    from cmpnt_prop_float f  
union all
    select d.cmpnt_id, d.cmpnt_type_prop_id, d.dim1, d.dim2, decode(d.value,
                                trunc(d.value,'HH'), to_char(d.value, 'YYYY-MM-DD'),
                                trunc(d.value,'MI'), to_char(d.value, 'YYYY-MM-DD HH24:MI'),
                                to_char(d.value, 'YYYY-MM-DD HH24:MI:SS'))
    from cmpnt_prop_date d
union all
    select s.cmpnt_id, s.cmpnt_type_prop_id, s.dim1, s.dim2, s.value
   from cmpnt_prop_string s;


create synonym s_cmpnt_prop_val_live for v_cmpnt_prop_val;

-- Change the initrans value of tables to support serializable transactions.
-- Must be at least 3

alter table cmpnt initrans 5 maxtrans 255;
alter table cmpnt_prop initrans 5 maxtrans 255;
alter table cmpnt_prop_fk_cmpnt initrans 5 maxtrans 255;
alter table cmpnt_prop_bool initrans 5 maxtrans 255;
alter table cmpnt_prop_integer initrans 5 maxtrans 255;
alter table cmpnt_prop_float initrans 5 maxtrans 255;
alter table cmpnt_prop_string initrans 5 maxtrans 255;
alter table cmpnt_prop_date initrans 5 maxtrans 255;
alter table cmpnt_prop_blob initrans 5 maxtrans 255;

alter table cmpnt_type initrans 5 maxtrans 255;
alter table cmpnt_type_prop initrans 5 maxtrans 255;
alter table cmpnt_type_prop_cats initrans 5 maxtrans 255;
alter table cmpnt_type_prop_dom initrans 5 maxtrans 255;
alter table cmpnt_type_prop_dim initrans 5 maxtrans 255;
alter table cmpnt_type_prop_req initrans 5 maxtrans 255;
alter table cmpnt_type_prop_def initrans 5 maxtrans 255;

alter table segments initrans 5 maxtrans 255;
alter table zones initrans 5 maxtrans 255;
alter table zone_links initrans 5 maxtrans 255;

alter table cmpnt_owners initrans 5 maxtrans 255;
alter table cmpnt_type_owners initrans 5 maxtrans 255;
alter table cmpnt_type_prop_owners initrans 5 maxtrans 255;





/*
CREATE INDEX XIF1cmpnt_prop_fk_cmpnt ON cmpnt_prop_fk_cmpnt (cmpnt_id   ASC,cmpnt_type_prop_id   ASC);
CREATE INDEX XIF1cmpnt_prop_bool ON cmpnt_prop_bool (cmpnt_id   ASC,cmpnt_type_prop_id   ASC);
CREATE INDEX XIF1cmpnt_prop_integer ON cmpnt_prop_integer (cmpnt_id   ASC,cmpnt_type_prop_id   ASC);
CREATE INDEX XIF1cmpnt_prop_float ON cmpnt_prop_float (cmpnt_id   ASC,cmpnt_type_prop_id   ASC);
CREATE INDEX XIF1cmpnt_prop_string ON cmpnt_prop_string (cmpnt_id   ASC,cmpnt_type_prop_id   ASC);
CREATE INDEX XIF1cmpnt_prop_date ON cmpnt_prop_date (cmpnt_id   ASC,cmpnt_type_prop_id   ASC);
CREATE INDEX XIF1cmpnt_prop_blob ON cmpnt_prop_blob (cmpnt_id   ASC,cmpnt_type_prop_id   ASC);
*/


CREATE INDEX XIF2cmpnt_prop_fk_cmpnt ON cmpnt_prop_fk_cmpnt (cmpnt_type_prop_id, cmpnt_id);
CREATE INDEX XIF2cmpnt_prop_bool ON cmpnt_prop_bool (cmpnt_type_prop_id, cmpnt_id);
CREATE INDEX XIF2cmpnt_prop_integer ON cmpnt_prop_integer (cmpnt_type_prop_id, cmpnt_id);
CREATE INDEX XIF2cmpnt_prop_float ON cmpnt_prop_float (cmpnt_type_prop_id, cmpnt_id);
CREATE INDEX XIF2cmpnt_prop_string ON cmpnt_prop_string (cmpnt_type_prop_id, cmpnt_id);
CREATE INDEX XIF2cmpnt_prop_date ON cmpnt_prop_date (cmpnt_type_prop_id, cmpnt_id);
CREATE INDEX XIF2cmpnt_prop_blob ON cmpnt_prop_blob (cmpnt_type_prop_id, cmpnt_id);




-- Database link and materialized view for staff info.
-- The critical fields of the staff table are 
--      staff_id, username, firstname, lastname
-- create database link prod01 connect to elog_reader identified by ? using '?';

/* Daily refresh = sysdate + 1 */


/*
CREATE materialized view staff
REFRESH FORCE
START WITH SYSDATE NEXT SYSDATE+1 
AS SELECT * FROM support.staff@prod01 where username is not null;
*/


/*
Trigger to maintain a checksum column (value_md5) in the cmpnt_prop_blob
table for use in comparing whether blob contents differ between 2 CED
installations.
*/

CREATE OR REPLACE TRIGGER set_value_md5
BEFORE INSERT OR UPDATE
ON CMPNT_PROP_BLOB

FOR EACH ROW

DECLARE hash VARCHAR2(32);

BEGIN

    hash := RAWTOHEX(
        DBMS_CRYPTO.HASH (
            typ => DBMS_CRYPTO.HASH_MD5,
            src => :new.value
        )
    );
  
  :new.value_md5 := hash;
   
END;
/



-- The trigger below references this procedure, so create it first

/*
procedure to rotate the synonym that chooses between 
view and materialized view.
*/
CREATE OR REPLACE PROCEDURE expire_inventory_synonym
IS
  PRAGMA AUTONOMOUS_TRANSACTION;

  POINTS_TO VARCHAR2(255);

BEGIN
  SELECT TABLE_NAME
  INTO POINTS_TO
  FROM USER_SYNONYMS 
  WHERE SYNONYM_NAME = 'S_CMPNT_PROP_VAL_LIVE';

  IF POINTS_TO = 'MV_CMPNT_PROP_VAL_LIVE'
  THEN
    -- POINT IT TO THE REGULAR VIEW INSTEAD.
    -- MUST DO SO AS AN AUTONOMOUS TRANSACTION
    -- SO THAT THE DROP/CREATE SYNONYM DDL DOES NOT
    -- IMPLICITLY COMMIT ANY TRANSACTION CURRENTLY UNDERWAY.
    -- DBMS_OUTPUT.PUT_LINE('IT POINTS TO '||POINTS_TO);

    -- PERFORMING DDL INSIDE PL/SQL REQUIRES THE USE OF
    -- ORACLE EXECUTE IMMEDIATE CALL
    EXECUTE IMMEDIATE 
      'DROP SYNONYM S_CMPNT_PROP_VAL_LIVE';
    EXECUTE IMMEDIATE 
      'CREATE SYNONYM S_CMPNT_PROP_VAL_LIVE FOR V_CMPNT_PROP_VAL';

  END IF; 


END;
/



CREATE OR REPLACE PROCEDURE do_inventory_changed
IS

ws VARCHAR2(100);  -- workspace

BEGIN

  -- As a placeholder, do nothing for now
  return;

  SELECT dbms_wm.getworkspace INTO ws FROM dual;

  -- The update first as it will be more frequent
  UPDATE workspace_info 
  SET inventory_lastmod = sysdate 
  WHERE workspace = ws;
  
  -- If the update failed, try an insert.
  IF ( sql%rowcount = 0 )
  THEN
    INSERT INTO workspace_info 
      (workspace, inventory_lastmod)
    VALUES
      (ws, sysdate);
  END IF;
 
  -- If ws = 'LIVE' we may also need to rotate the
  -- synonym that chooses between view and materialized view
  IF ws = 'LIVE'
  THEN
    -- DBMS_OUTPUT.PUT_LINE('Must Also rotate synonym');
    expire_inventory_synonym;
  END IF;

END;
/


-- This trigger must be created before versioning is enabled.

/*
Trigger to record that the data in the workspace has been altered.
Relies on the fact that the API always touches the cmpnt_prop table
after modifying any of the cmpnt_prop_* tables.  If that were not true
then an equivalent trigger would have to be attached to each of those tables as well.
*/
CREATE OR REPLACE TRIGGER inventory_changed 
AFTER INSERT
OR UPDATE
OR DELETE
ON CMPNT_PROP

DECLARE ws VARCHAR2(100);  -- workspace

BEGIN

do_inventory_changed;

END;
/

