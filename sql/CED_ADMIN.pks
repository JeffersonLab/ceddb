CREATE OR REPLACE PACKAGE CED3_OWNER.CED_ADMIN
AUTHID CURRENT_USER
IS

/**
*========================================================================<br/>
* A package to aid administration of multiple CED schemas.  Includes procedures
* for copying data among the different schemas and the workspaces they may contain.
* Also includes procedures to enable selective merging and refreshing of CED inventory
* and catalog elements within the workspaces of a single schema.
*
*   Note on Semantics:
*       -- install* functions delete all rows and insert new ones.
*       -- copy* and checkout* functions will selectively delete/insert/update rows at the target
*          as minimally necessary to make them mirror the source.
*
* @todo might be nice to create a procedure that creates in the local database all the workspaces
*  at a remote database and then copies the appropriate data into each.
*
* @todo add a utility function to purge the foreign keys pointing into a type hierarchy
  Example to remove all FK referencing Magnets:
  delete from cmpnt_prop where (cmpnt_id, cmpnt_type_prop_id) in
    (select cmpnt_id, cmpnt_type_prop_id from
     cmpnt_prop_fk_cmpnt where value in (
     select cmpnt_id from cmpnt where cmpnt_type_id in (
     select cmpnt_type_id from cmpnt_type
     start with cmpnt_type_id=96000
     connect by prior cmpnt_type_id = parent_cmpnt_type_id)));
  delete from segments where start_cmpnt in (
    select cmpnt_id from cmpnt where cmpnt_type_id in (
    select cmpnt_type_id from cmpnt_type
    start with cmpnt_type_id=96000
    connect by prior cmpnt_type_id = parent_cmpnt_type_id));
  delete from segments where end_cmpnt in (
    select cmpnt_id from cmpnt where cmpnt_type_id in (
    select cmpnt_type_id from cmpnt_type
    start with cmpnt_type_id=96000
    connect by prior cmpnt_type_id = parent_cmpnt_type_id));

  * Or howabout a rapid purge
  1) Remove FK dependencies
  2) delete from cmpnt where cmpnt_type_id in (
    select cmpnt_type_id from cmpnt_type
    start with cmpnt_type_id=96000
    connect by prior cmpnt_type_id = parent_cmpnt_type_id);



* @headcom
*/

-- CONSTANTS

/**
*  The name of the schema used as CEDOPS.
*  CEDOPS will not be workspace manager version-enabled.
*/
CEDOPS CONSTANT VARCHAR2(20) := 'CED3_OPS';

/**
*  The name of the schema defined as CEDDEV
*  CEDDEV will be workspace manager version-enabled and may contain
*  various developmental workspaces at any given time.
*
*  @note: There seems to be a bug in oracle that prevents versioning if the
*         schema below is 8 chars, hence devl instead of dev is used.
*/
CEDDEV CONSTANT VARCHAR2(20) := 'CED3_DEVL';

/**
*  The name of the schema defined as CEDHIST
*  CEDDEV will be workspace manager version-enabled and
*  will contain named savepoints preserving historical state of
*  CEDOPS.
*/
CEDHIST CONSTANT VARCHAR2(20) := 'CED3_HIST';



-- EXCEPTIONS

/**
* Exception raised if an attempt is made to recreate the CEDSRC database link.
* Prior existence of the CEDSRC link may mean another install/copy is taking place.
* as such it functions as a lock file.
*/
CEDSRC_EXIST EXCEPTION;


/**
* Exception raised if an element name does not exist
*/
ELEM_NOT_FOUND EXCEPTION;

/**
* Exception raised if a mismatch occurs between the number of source and
* destination after a copy or install operation.
*/
ROW_COUNT_MISMATCH EXCEPTION;


/**
* The current event_id for grouping related events
*/
eventID INTEGER := null;

/**
* The value to which the ack flag will be set for history event table insertions
* Setting it to 1 will make the events pre-acknowledged and therefore ignored by the
* ced_notify external procedure.
*/
eventACK SMALLINT := 0;


/**
* The current event_id for grouping related events
*/
suppressHistory BOOLEAN := FALSE;



/**
* Defines an array of strings useful for enumerating various sets of CED tables
*/
TYPE tables_list IS VARRAY(30) OF VARCHAR2(45);



/**
* CED Table inventory.
* The list is in the order from which data must be deleted
* to avoid foreign-key constraint issues.  Some may not need
* to be deleted explicitly because cascading delete does the work.
*/
ced_tables    tables_list := tables_list(
    'ZONES',
    'SEGMENTS',
    'ZONE_LINKS',
    'CMPNT_PROP_FK_CMPNT',
    'CMPNT',
    'CMPNT_OWNERS',
    'CMPNT_PROP',
    'CMPNT_PROP_BLOB',
    'CMPNT_PROP_BOOL',
    'CMPNT_PROP_DATE',
    'CMPNT_PROP_FLOAT',
    'CMPNT_PROP_INTEGER',
    'CMPNT_PROP_STRING',
    'CMPNT_TYPE',
    'CMPNT_TYPE_OWNERS',
    'CMPNT_TYPE_PROP',
    'CMPNT_TYPE_PROP_CATS',
    'CATEGORY_SETS',
    'CMPNT_TYPE_PROP_DOM',
    'CMPNT_TYPE_PROP_DEF',
    'CMPNT_TYPE_PROP_DIM',
    'CMPNT_TYPE_PROP_REQ',
     'CMPNT_TYPE_PROP_MIX',
    'CMPNT_TYPE_PROP_OWNERS'
 );


/**
* Lists the tables used by CED for inventory purposes.
* Sorted in the order which they must be refreshed or merged to to avoid foreign-key
* constraint issues among themselves.  These tables all have cmpnt_id
* as part or all of their primary key.
*/
inventory_tables    tables_list := tables_list(
    'CMPNT',
    'CMPNT_PROP',
    'CMPNT_PROP_BLOB',
    'CMPNT_PROP_BOOL',
    'CMPNT_PROP_DATE',
    'CMPNT_PROP_FK_CMPNT',
    'CMPNT_PROP_FLOAT',
    'CMPNT_PROP_INTEGER',
    'CMPNT_PROP_STRING',
    'CMPNT_OWNERS'
 );


/**
* Lists the tables used by CED for zone definition purposes in the order
* which they must be refreshed or merged to to avoid foreign-key
* constraint issues among themselves.
*/
zone_tables    tables_list := tables_list(
    'ZONES',
    'SEGMENTS',
    'ZONE_LINKS'
);



/**
* Lists the tables used by CED for catalog purposes in the order
* which they must be refreshed or merged to to avoid foreign-key
* constraint issues among themselves.
*/
catalog_tables    tables_list := tables_list(
    'CMPNT_TYPE',
    'CATEGORY_SETS',
    'CMPNT_TYPE_PROP_CATS',
    'CMPNT_TYPE_PROP',
    'CMPNT_TYPE_PROP_DOM',
    'CMPNT_TYPE_PROP_DEF',
    'CMPNT_TYPE_PROP_DIM',
    'CMPNT_TYPE_PROP_REQ',
    'CMPNT_TYPE_PROP_MIX',
    'CMPNT_TYPE_OWNERS',
    'CMPNT_TYPE_PROP_OWNERS'
 );



/**
* Lists the (nearly) identical tables that hold property values.
* Note that the CMPNT_PROP_BLOB has extra fields and a blob column
* that may preclude treating it identically to the others in some circumstances
*/
value_tables  tables_list := tables_list(
    'CMPNT_PROP_BLOB',
    'CMPNT_PROP_BOOL',
    'CMPNT_PROP_DATE',
    'CMPNT_PROP_FK_CMPNT',
    'CMPNT_PROP_FLOAT',
    'CMPNT_PROP_INTEGER',
    'CMPNT_PROP_STRING'
 );




/**
* Automates granting of appropriate permissions on the current schema to the
* READ_CED and OWN_CED roles.  It is best to run it on the CED schema while
* tables are not version-enabled.
*/
PROCEDURE grantPermissions;


/**
* Installs data from a local source.
* First deletes the entire contents of current schema and workspace and replaces it
* wholesale with the data from a local wrkspc in schema2use.  OK for putting
* data into unversioned schema (e.g. CEDOPS), but not good to use for versioned schema
* because it will generate excessive history by deleting and reinserting even unchanged rows.
*
* @param wrkspc The name of the workspace from which to copy
* @param schema2use The name of the schema from which to copy
* @param updateSequences Whether to synchronize the sequences with the source.
*/
PROCEDURE installWorkspace (wrkspc IN VARCHAR2, schema2use IN VARCHAR2,
                            updateSequences IN BOOLEAN DEFAULT FALSE);


/**
* Installs data from a remote source.
* First deletes the entire contents of current schema and workspace and replaces it
* wholesale with the data from wrkspc@CEDSRC where CEDSRC is a database link to be created using
* the connection details provided to the procedure.  InstallWorkspace is suitable for putting
* data into unversioned schema (e.g. CEDOPS), but not good to use for versioned schema
* because it will generate excessive history by deleting and reinserting even unchanged rows.
*
* @param wrkspc The name of the workspace from which to copy
* @param schema2use The name of the schema from which to copy
* @param passwd2use The password to connect to schema2use
* @param db2use The service identifier (ceddb01, cedtestm etc.) of the soruce database
* @param updateSequences Whether to synchronize the sequences with the source.
*/

PROCEDURE installWorkspace (wrkspc IN VARCHAR2, schema2use IN VARCHAR2,
                            passwd2use IN VARCHAR2, db2use IN VARCHAR2,
                            updateSequences IN BOOLEAN DEFAULT FALSE);


/**
* Copies data from a local source.
* Selectively deletes unneeded data in the current schema and applies inserts and
* updates as minimally necessary to synchronize with the source schema.  This is generally
* the fastest and most efficient means of copying data between two workspaces.  It is suitable
* for use with both versioned and unversioned schemas
* @param wrkspc The name of the workspace from which to copy
* @param schema2use The name of the schema from which to copy
*/
PROCEDURE copyWorkspace (wrkspc IN VARCHAR2, schema2use IN VARCHAR2, savepoint IN VARCHAR2 default NULL);


/**
* Copies data from a remote source.
* Selectively deletes unneeded data in the current schema and applies inserts and
* updates as minimally necessary to synchronize with the source schema.  This is generally
* the fastest and most efficient means of copying data between two workspaces.  It is suitable
* for use with both versioned and unversioned schemas
*
* @param wrkspc The name of the workspace from which to copy
* @param schema2use The name of the schema from which to copy
* @param passwd2use The password to connect to schema2use
* @param db2use The service identifier (ceddb01, cedtestm etc.) of the source database
*/
PROCEDURE copyWorkspace (wrkspc IN VARCHAR2, schema2use IN VARCHAR2,
                            passwd2use IN VARCHAR2, db2use IN VARCHAR2);

/**
* Copies the contents of schema referenced by the CEDOPS constant and schema to
* the LIVE workspace of schema referenced by the CEDHIST constant and then creates
* a savepoint.  If a savepoint name is not provided, then one is sequentially auto-generated.
*
*
* @param savePoint The name for the savepoint
* @param savePointDescription The description of the savepoint
* @param password2Use The password to connect to OPS CED
* @param database2Use  The SQLNet name of the instance housing OPS CED (e.g. CEDDB01)
*/
PROCEDURE saveCEDOPStoHistory (
                                password2Use IN VARCHAR2 DEFAULT NULL,
                               database2Use IN VARCHAR2 DEFAULT NULL,
                               savePointName IN VARCHAR2 DEFAULT NULL,
                               savePointDescription IN VARCHAR2 DEFAULT NULL);



/**
* Copies the contents of a savepoint into the CEDOPS schema.
* If no savepoint is specified, the most recent contents of CEDHIST will be restored.
*
* @param savePoint The name of the savepoint to restore
*/
PROCEDURE restoreCEDOPSFromHistory  (savePointName IN VARCHAR2 DEFAULT NULL);



/**
* Copies the contents of schema referenced by the CEDOPS constant into the current schema
* and workspace. A convenience function equivalent to executing copyWorkspace('LIVE',CED_ADMIN.CEDOPS)
*/
PROCEDURE checkoutCEDOPS;


/**
* Begins a notifyEvent by setting package variable eventID to non-null.
*/
PROCEDURE beginHistEvent;


/**
* Begins a notifyEvent by setting package variable eventID to null.
*/
PROCEDURE endHistEvent (sessionEnding BOOLEAN DEFAULT FALSE);


/**
* Enables ced_notification events (the default)
*/
PROCEDURE enableCEDNotify;


/**
* Disables ced_notification events (the default)
*/
PROCEDURE disableCEDNotify;



/**
* Checks to see if notification has been turned on via beginNotifyEvent and if so,
* puts a row into the notify_events table using the provided data.
*
* @param tableName
* @param actionFlag (I|U|D)
* @param cmpntID The relevant cmpnt_id
* @param propID  The relevant cmpnt_type_prop_id
* @param dim1 Array dimension 1 of a val table
* @param dim2 Array dimension 2 of a val table
* @param oldValue for updates and deletes
* @param newValue for updates and inserts
*/
PROCEDURE doHistCmpntPropVal(tableName IN VARCHAR2, actionFlag IN CHAR,
                        cmpntID IN INTEGER, propID in INTEGER,
                        dim1 IN INTEGER DEFAULT NULL, dim2 IN INTEGER DEFAULT NULL,
                        oldValue in VARCHAR2 DEFAULT NULL, newValue in VARCHAR2 DEFAULT NULL);



/**
* Puts a row into the hist_cmpnt_prop table.
*
* @param actionFlag (I|U|D)
* @param cmpntID The relevant cmpnt_id
* @param propID  The relevant cmpnt_type_prop_id
* @param oldComments for updates and deletes
* @param newComments for updates and inserts
* @param oldSetBy for updates and deletes
* @param newSetBy for updates and inserts
* @param oldModifyDate for updates and deletes
* @param newModifyDate for updates and inserts
*/
PROCEDURE doHistCmpntProp(actionFlag IN CHAR,
                        cmpntID IN INTEGER, propID in INTEGER,
                        oldComments IN VARCHAR2 DEFAULT NULL, newComments IN VARCHAR2 DEFAULT NULL,
                        oldSetBy IN VARCHAR2 DEFAULT NULL, newSetBy IN VARCHAR2 DEFAULT NULL,
                        oldModifyDate in TIMESTAMP DEFAULT NULL, newModifyDate in TIMESTAMP DEFAULT NULL);


/**
* Puts a row into the hist_cmpnt table.
*
* @param actionFlag (I|U|D)
* @param cmpntID The relevant cmpnt_id
* @param oldName for updates and deletes
* @param newName for updates and inserts
* @param oldTypeId for updates and deletes
* @param newTypeId for updates and inserts
*/
PROCEDURE doHistCmpnt ( actionFlag IN CHAR,
                        cmpntID IN INTEGER,
                        oldName IN VARCHAR2 DEFAULT NULL, newName IN VARCHAR2 DEFAULT NULL,
                        oldTypeId IN INTEGER DEFAULT NULL, newTypeId IN INTEGER DEFAULT NULL);


/**
* Performs a table by table refresh of the specified workspace.
* (updates the workspace with changes from its parent)
* Defaults to refreshing ALL tables, but can optionally refresh
* just the CATALOG, INVENTORY or ZONE tables.  If an Oracle exception is encountered,
* outstanding refreshes will be rolled back.  Otherwise, it is the caller's duty to
* commit or rollback the data after a successful execution.
*
* @param wrkspc The name of the workspace to be refreshed
* @param tableSet ALL|CATALOG|INVENTORY|ZONE
*/
PROCEDURE refresh (wrkspc IN VARCHAR2, tableSet IN VARCHAR2 DEFAULT 'ALL');


/**
* Performs a table by table merge of the specified workspace.
* (updates the parent workspace with changes from specified child)
* Defaults to refreshing ALL tables, but can optionally refresh
* just the CATALOG, INVENTORY or ZONE tables.  If an Oracle exception is encountered,
* outstanding merges will be rolled back.  Otherwise, it is the caller's duty to
* commit or rollback the data after a successful execution.
*
* @param wrkspc The name of the workspace to be merged
* @param tableSet ALL|CATALOG|INVENTORY|ZONE
*/
PROCEDURE merge (wrkspc IN VARCHAR2, tableSet IN VARCHAR2 DEFAULT 'ALL');

/**
* Merges a single element into parent workspace.
* Only operates on INVENTORY tables, so may fail if the
* CATALOG tables are out of sync between parent and child workspaces.
* This function can't be used to merge an element that was deleted - use
* mergeElementByID instead.
*
*
* @param wrkspc The name of the workspace containing element to be merged
* @param elem The name of the element to merge
* @throws ELEM_NOT_FOUND if the element does not exist as name in cmpnt table.
*/
PROCEDURE mergeElementByName (wrkspc IN VARCHAR2, elem IN VARCHAR2);


/**
* Merges a single element into parent workspace.
* Only operates on INVENTORY tables, so may fail if the
* CATALOG tables are out of sync between parent and child workspaces.
*
* @param wrkspc The name of the workspace containing element to be merged
* @param cmpnt_id The id of the element to merge
*/
PROCEDURE mergeElementByID (wrkspc IN VARCHAR2, cmpnt_id IN INTEGER);


/**
* Creates temporary tables used to stage data being copied between workspaces.
* In Oracle, temporary tables aren't really temporary.  The data in them is temporary
* and will disappear at the end of a session or of a transaction depending on the option
* with which the temp table is created.  As such, it's best to
* create the tables once and then leave them around.  The temporary tables are named
* identically to the source table with a t_ prepended.
*/
PROCEDURE createStageTables;


/**
* Truncates and drops all the t_* temp tables in the current schema that were created
* by createStageTables.
*/
PROCEDURE dropStageTables;



/**
* Enables versioning for CED tables set.
*/
PROCEDURE enableVersioning;


/**
* Disables versioning for CED tables set.
* @todo Improve by removing all workspaces first?
*/
PROCEDURE disableVersioning;


/**
* Return a string that identifies the current database instance
* as a particular CED deployment name (ced, led, etc.)
*/
FUNCTION currentDeployment RETURN VARCHAR2;





/*

--  The following procedures have not yet been implemented.

-- Refreshes a single element into parent workspace
PROCEDURE refreshElementByName (elem IN VARCHAR2, wrkspc IN VARCHAR2);

-- Copies the contents of CEDHIST savePointName to the current CEDDEV schema/workspace
PROCEDURE checkoutHistory   (savePointName IN VARCHAR2 DEFAULT NULL);

-- Deletes the contents of CEDOPS and replaces it with the data from savePointName in CEDHIST
-- Performs only deletes and inserts, which is suitable b/c CEDOPS is not version-enabled
PROCEDURE installHistory (savePointName IN VARCHAR2 DEFAULT 'LATEST');

*/




END CED_ADMIN;  -- End of Package Declaration
/

