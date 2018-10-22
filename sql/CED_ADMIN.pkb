CREATE OR REPLACE PACKAGE BODY CED3_OWNER.CED_ADMIN
AS


/**
* Private Procedures Declaration
*/

/**
* Creates CEDSRC database link using the provided connection parameters.
*
* @param schema2use The name of the schema from which to copy
* @param passwd2use The password to connect to schema2use
* @param db2use The service identifier (ceddb01, cedtestm etc.) of the source database
* @throws CED_SRC_EXIST if the dblink already exists implying an active lock.
*/
PROCEDURE createCEDSrc (schema2use IN VARCHAR2, passwd2use IN VARCHAR2, db2use IN VARCHAR2);

/**
* Creates a database to nowhere that to serve as a lock.
* @throws CED_SRC_EXIST if the dblink already exists implying an active lock.
*/
PROCEDURE createCEDSrc;


/**
* Creates indexes on key Stage tables to improve performance.
* And to prevent large hash joins that may tickle Oracle bug 6664976
* [METALINK ID 557293.1] which is not fixed until 11.1.0.8
*/
PROCEDURE indexStageTables;


/**
* Copies data from each CED table@CEDSRC and stores it in corresponding local temp table
* named as 't_' prefixed onto original name.
*   For example: cmpnt@CEDSRC table gets stashed into t_cmpnt
*/
PROCEDURE fillStageTablesFromCEDSrc(wrkspc IN VARCHAR2);

/**
* Copies data from each schema2use.table and stores it in corresponding temp
* table in target schema named as 't_' prefixed onto original name.
*   For example: schema2use.cmpnt table stashed into origSchema.t_cmpnt
* @param wrkspc The name of the workspace from which to copy
* @param schema2use The name of the schema from which to copy
*/
PROCEDURE fillStageTablesFromSchema(wrkspc IN VARCHAR2, schema2use IN VARCHAR2, savepoint IN VARCHAR2 default NULL);


/**
* Compares number of rows in each table between the temp tables and current schema.
* It is run at the end of copy/install methods as a sanity check.
*
* @param throwOnMismatch When set to FALSE, will suppress throwing of a ROW_COUNT_MISMATCH exception.
* @throws ROW_COUNT_MISMATCH if number of rows in schema doesn't match rows in stage tables.
*/
PROCEDURE compareRowCounts (throwOnMismatch BOOLEAN DEFAULT TRUE);


/**
* Does the work common to both installWorkspace procedures.
*/
PROCEDURE doInstallWorkspace (updateSequences IN BOOLEAN DEFAULT FALSE);

/**
* Does the work common to both copyWorkspace procedures.
*/
PROCEDURE doCopyWorkspace;


/**
* Closes and drops the database link name CEDSRC.
* Failure to remove the link will prevent future executions of install or
* copy procedures in this package.
*
*/
PROCEDURE removeCEDSrc(closeDBLink IN BOOLEAN DEFAULT TRUE);

/**
* Removes rows from schema tables that don't exist in corresponding t_* staging tables.
*/
PROCEDURE removeData;




/**
* Update the non-key columns of each local table to match the values of the corresponding
* columns in the staged t_* temp tables
*
*/
PROCEDURE updateData;

/**
* Brute force deletion of all data in the tables.  No attempt is made to limit what gets
* deleted.  It's all thrown out.
*/
PROCEDURE purgeData;


/**
* Inserts rows into schema CED tables that exist in t_* staging tables, but don't currently exist
* in current schema tables.
*/
PROCEDURE insertData;


/**
* Updates sequences to start after the max current val for
* each sequence that was stored previously into t_user_sequences
*
* To enable creation of elements in a newly copied database, the sequences in the new
* copy must be updated to start at a higher number than where the source database left off.
* This procedures assumes the pre-existence of the t_user_sequences temporary table.
*
*/
PROCEDURE doUpdateSequences;



FUNCTION check_event_id_currval RETURN INTEGER;

/**
* Wrapper for outputting errors, warnings, etc.
* Uses an autonomous transaction to write to admin_log table
* which may be monitored for status of long-running procedures.
* (We do this because there's no way to make Oracle flush the
* output of DBMS_OUTPUT.PUT_LINE calls that it's buffering until a
* procedure completes.
*
* @param msg The text to send to the log
* @param schema2use The schema into whose admin_log table to write
*/
PROCEDURE logMsg(msg IN VARCHAR2, schema2use IN VARCHAR2 DEFAULT NULL);


/**
* ------------------------------
*/


/**
* Automates granting of appropriate permissions on the current schema to the
* READ_CED and OWN_CED roles.  It is best to run it on the CED schema while
* tables are not version-enabled.
*/
PROCEDURE grantPermissions
IS
sqlStr VARCHAR2(1000);


CURSOR table_cur IS SELECT table_Name FROM user_tables;
CURSOR view_cur IS SELECT view_Name FROM user_views;
CURSOR seq_cur IS SELECT sequence_Name FROM user_sequences;


BEGIN

    logMsg ('Begin grantPermissions');

    FOR t in table_cur
    LOOP
        sqlStr := 'GRANT SELECT ON '||t.table_name||' to READ_CED';
        EXECUTE IMMEDIATE sqlStr;
        --logMsg(sqlStr);
        sqlStr := 'GRANT ALL ON '||t.table_name||' to OWN_CED';
        EXECUTE IMMEDIATE sqlStr;
        logMsg(sqlStr);
    END LOOP;

    FOR v in view_cur
    LOOP
        sqlStr := 'GRANT SELECT ON '||v.view_name||' to READ_CED';
        EXECUTE IMMEDIATE sqlStr;
        --logMsg(sqlStr);
    END LOOP;

    FOR s in seq_cur
    LOOP
        sqlStr := 'GRANT SELECT ON '||s.sequence_name||' to READ_CED';
        EXECUTE IMMEDIATE sqlStr;
        --logMsg(sqlStr);
    END LOOP;

    -- Special Tables
    sqlStr := 'GRANT INSERT ON admin_log to READ_CED';
    EXECUTE IMMEDIATE sqlStr;
    sqlStr := 'GRANT INSERT ON usage_log to READ_CED';
    EXECUTE IMMEDIATE sqlStr;

    -- The final Grant may fail on non-owner CEDs, but that's ok.
    -- sqlStr := 'GRANT ALL ON web_auth to READ_CED';
    -- EXECUTE IMMEDIATE sqlStr;

    logMsg ('End grantPermissions');

END;




/**
* Enables versioning for CED tables set.
*/
PROCEDURE enableVersioning
IS
BEGIN
    -- Table names must be specified with parent table before child in FK relationships
    DBMS_WM.EnableVersioning ('cmpnt_type, cmpnt_type_owners, cmpnt, cmpnt_owners, cmpnt_type_prop, cmpnt_prop, cmpnt_type_prop_def, cmpnt_type_prop_dom, cmpnt_type_prop_dim, cmpnt_type_prop_req, cmpnt_type_prop_mix, cmpnt_type_prop_owners, cmpnt_type_prop_cats, category_sets, cmpnt_prop_fk_cmpnt, cmpnt_prop_bool, cmpnt_prop_integer, cmpnt_prop_float, cmpnt_prop_string, cmpnt_prop_date, cmpnt_prop_blob, zones, zone_links, segments', 'VIEW_WO_OVERWRITE');
END;



/**
* Disables versioning for CED tables set.
* @todo Improve by removing all workspaces first?
*/
PROCEDURE disableVersioning
IS
BEGIN
    -- Table names must be specified with parent table before child in FK relationships
    DBMS_WM.DisableVersioning ('cmpnt_type, cmpnt_type_owners, cmpnt, cmpnt_owners, cmpnt_type_prop, cmpnt_prop, cmpnt_type_prop_def, cmpnt_type_prop_dom, cmpnt_type_prop_dim, cmpnt_type_prop_req, cmpnt_type_prop_mix, cmpnt_type_prop_owners, cmpnt_type_prop_cats, category_sets, cmpnt_prop_fk_cmpnt, cmpnt_prop_bool, cmpnt_prop_integer, cmpnt_prop_float, cmpnt_prop_string, cmpnt_prop_date, cmpnt_prop_blob, zones, zone_links, segments');
END;



/**
* ------------------------------
*/



/**
* Creates temporary tables used to stage data being copied between workspaces.
* In Oracle, temporary tables aren't really temporary.  The data in them is temporary
* and will disappear at the end of a session or of a transaction depending on the option
* with which the temp table is created.  As such, it's best to
* create the tables once and then leave them around.  The temporary tables are named
* identically to the source table with a t_ prepended.
*/
PROCEDURE createStageTables
IS
sqlStr VARCHAR2(1000);
t_name VARCHAR2(25);

BEGIN

    logMsg ('Begin createStageTables');

    -- We use deletion tables list just because it has all table names
    FOR n in 1 .. ced_tables.count
    LOOP
      sqlStr := 'create global temporary table t_'||ced_tables(n)
                ||' on commit delete rows as select * from '||ced_tables(n);
      --logMsg(sqlStr);
      EXECUTE IMMEDIATE  sqlStr;
    END LOOP;


    sqlStr := 'create global temporary table t_user_workspaces
                on commit preserve rows
                as select * from user_workspaces';
    EXECUTE IMMEDIATE  sqlStr;


    -- we need preserve rows here because we may loop over the data
    -- and create the sequences anew.  We don't want the first implicit commit
    -- following a "create sequence" DDL to remove the data.  We want it to persist
    -- for the session.
    sqlStr := 'create global temporary table t_user_sequences
                on commit preserve rows
                as select * from user_sequences';
    EXECUTE IMMEDIATE  sqlStr;

    -- Go ahead and create the indexes right away.
    indexStageTables;

END;

/**
* ------------------------------
*/


/**
* Creates indexes on key Stage tables to improve performance.
* And to prevent large hash joins that may tickle Oracle bug 6664976
* [METALINK ID 557293.1] which is not fixed until 11.1.0.8
*/
PROCEDURE indexStageTables
IS
sqlStr VARCHAR2(1000);
t_name VARCHAR2(25);

BEGIN

    logMsg ('Begin indexStageTables');

    -- Will fail to create indexes and get an error if the temp tables are already
    -- storing data when we attempt to index them, so we truncate them first
    FOR n in 1 .. ced_tables.count
    LOOP
      sqlStr := 'truncate table t_'||ced_tables(n);
      --logMsg(sqlStr);
     EXECUTE IMMEDIATE  sqlStr;

    END LOOP;


    -- Make indexes on large stage tables to prevent hash join error?
    FOR n in 1 .. value_tables.count
    LOOP
      sqlStr := 'create unique index idxt_'||value_tables(n)||' on t_'||value_tables(n)
                ||' (cmpnt_id, cmpnt_type_prop_id, dim1, dim2) ';
     --logMsg(sqlStr);
     EXECUTE IMMEDIATE  sqlStr;

    END LOOP;

    sqlStr := 'create unique index idxt_cmpnt on t_cmpnt (cmpnt_id)';
    --logMsg(sqlStr);
    EXECUTE IMMEDIATE  sqlStr;

    sqlStr := 'create unique index idxt_cmpnt_type on t_cmpnt_type (cmpnt_type_id)';
    --logMsg(sqlStr);
    EXECUTE IMMEDIATE  sqlStr;

    sqlStr := 'create unique index idxt_cmpnt_prop on t_cmpnt_prop (cmpnt_id, cmpnt_type_prop_id)';
    --logMsg(sqlStr);
    EXECUTE IMMEDIATE  sqlStr;

    sqlStr := 'create unique index idxt_cmpnt_type_prop on t_cmpnt_type_prop (cmpnt_type_prop_id)';
    --logMsg(sqlStr);
    EXECUTE IMMEDIATE  sqlStr;


END;

/**
* ------------------------------
*/

/**
* Copies data from each CED table@CEDSRC and stores it in corresponding local temp table
* named as 't_' prefixed onto original name.
*   For example: cmpnt@CEDSRC table gets stashed into t_cmpnt
*
* @todo use SET TRANSACTION ISOLATION LEVEL READONLY  or maybe better yet use DBMS_WM.FREEZEWORKSPACE
*/
PROCEDURE fillStageTablesFromCEDSrc(wrkspc IN VARCHAR2)
IS
sqlStr VARCHAR2(1000);
t_name VARCHAR2(25);

BEGIN

    logMsg ('Begin fillStageTablesFromCEDSrc');

    -- Set the desired workspace at the other end of the CEDDSRC link
    sqlStr := 'begin dbms_wm.gotoworkspace@CEDSRC('''||wrkspc||'''); end;';

    logMsg('Changing remote workspace: '||sqlStr);
    EXECUTE IMMEDIATE sqlStr;


    -- We use deletion tables list just because it has all table names
    FOR n in 1 .. ced_tables.count
    LOOP
      sqlStr := 'insert into t_'||ced_tables(n)
                ||' select * from '||ced_tables(n)||'@CEDSRC';
      --logMsg(sqlStr);
      EXECUTE IMMEDIATE  sqlStr;
    END LOOP;


    sqlStr := 'insert into t_user_workspaces select * from user_workspaces@CEDSRC';
    --logMsg(sqlStr);
    EXECUTE IMMEDIATE  sqlStr;

    sqlStr := 'insert into t_user_sequences select * from user_sequences@CEDSRC';
    --logMsg(sqlStr);
    EXECUTE IMMEDIATE  sqlStr;

END;


/**
* ------------------------------
*/

/**
* Copies data from each schema2use.table and stores it in corresponding temp
* table in target schema named as 't_' prefixed onto original name.
*   For example: schema2use.cmpnt table stashed into origSchema.t_cmpnt
* @param wrkspc The name of the workspace from which to copy
* @param schema2use The name of the schema from which to copy
*
* @todo use SET TRANSACTION ISOLATION LEVEL READONLY  or maybe better yet use DBMS_WM.FREEZEWORKSPACE
*/
PROCEDURE fillStageTablesFromSchema(wrkspc IN VARCHAR2, schema2use IN VARCHAR2, savepoint IN VARCHAR2 default NULL)
IS
sqlStr VARCHAR2(1000);

origWrkspc VARCHAR2(255);
origSchema VARCHAR2(255);


BEGIN

    logMsg ('Begin fillStageTablesFromSchema');
    -- Save original context
    origSchema := sys_context('USERENV', 'CURRENT_SCHEMA');
    origWrkspc := DBMS_WM.GetWorkspace();

    -- Set source context
    sqlStr := 'alter session set current_schema='||schema2use;
    EXECUTE IMMEDIATE  sqlStr;
    DBMS_WM.gotoWorkspace(wrkspc);

    -- Optionally choose a non-default savepoint
    IF savepoint IS NOT NULL
    THEN
        DBMS_WM.gotoSavepoint(savepoint);
    END IF;

    -- We use deletion tables list just because it has all table names
    FOR n in 1 .. ced_tables.count
    LOOP
      sqlStr := 'insert into '||origSchema||'.t_'||ced_tables(n)
                ||' select * from '||ced_tables(n);
      logMsg(sqlStr, origSchema);
      EXECUTE IMMEDIATE  sqlStr;
    END LOOP;


    sqlStr := 'insert into '||origSchema||'.t_user_workspaces
                (workspace, description)
                select workspace, description
                from all_workspaces where owner = UPPER(:schema2use)';
    EXECUTE IMMEDIATE  sqlStr using schema2use;
    --logMsg(sqlStr,origSchema);


    sqlStr := 'insert into '||origSchema||'.t_user_sequences
                (sequence_name, min_value, max_value, increment_by,
                 cycle_flag, order_flag, cache_size, last_number)
                select sequence_name, min_value, max_value, increment_by,
                 cycle_flag, order_flag, cache_size, last_number
                from all_sequences where sequence_owner = UPPER(:schema2use)';
    EXECUTE IMMEDIATE  sqlStr using schema2use;
    --logMsg(sqlStr,origSchema);


    -- Restore original context before returning
    sqlStr := 'alter session set current_schema='||origSchema;
    EXECUTE IMMEDIATE  sqlStr;
    DBMS_WM.gotoWorkspace(origWrkspc);


    EXCEPTION
        WHEN OTHERS THEN
           ROLLBACK;
           -- Restore original context
           sqlStr := 'alter session set current_schema='||origSchema;
           EXECUTE IMMEDIATE  sqlStr;
           dbms_wm.gotoWorkspace(origWrkspc);
           logMsg('EXCEPTION: Oracle Error '||SQLCODE, origSchema);
           RAISE;       -- Re-throws


END;

/**
* ------------------------------
*/

/**
* Truncates and drops all the t_* temp tables in the current schema that were created
* by createStageTables.
*/
PROCEDURE dropStageTables
IS
sqlStr VARCHAR2(1000);
t_name VARCHAR2(25);

BEGIN

    logMsg ('Begin dropStageTables');

    -- cascade on delete will purge many of the sub-tables.
    FOR n in 1 .. ced_tables.count
    LOOP
      sqlStr := 'truncate table t_'||ced_tables(n);
      EXECUTE IMMEDIATE  sqlStr;
      --logMsg(sqlStr);

      sqlStr := 'drop table t_'||ced_tables(n);
      EXECUTE IMMEDIATE  sqlStr;
      --logMsg(sqlStr);

    END LOOP;

    sqlStr := 'truncate table t_user_workspaces';
    EXECUTE IMMEDIATE  sqlStr;
    sqlStr := 'drop table t_user_workspaces';
    EXECUTE IMMEDIATE  sqlStr;

    sqlStr := 'truncate table t_user_sequences';
    EXECUTE IMMEDIATE  sqlStr;
    sqlStr := 'drop table t_user_sequences';
    EXECUTE IMMEDIATE  sqlStr;

END;


/**
* ------------------------------
*/


/**
*  Does the work common to both installWorkspace procedures
*
* @param updateSequences Whether to synchronize the sequences with the source.
*
* @todo SET TRANSACTION ISOLATION LEVEL SERIALIZABLE  or maybe better yet use DBMS_WM.FREEZEWORKSPACE
*/
PROCEDURE doInstallWorkspace (updateSequences IN BOOLEAN DEFAULT FALSE)
IS

sqlStr VARCHAR2(1000);

BEGIN

    -- We need to prevent hash joins to avoid tickling Oracle bug 6664976
    -- [METALINK ID 557293.1] which is not fixed until 11.1.0.8
    -- sqlStr := 'alter session set "_hash_join_enabled"=FALSE';
    -- EXECUTE IMMEDIATE sqlStr;

    purgeData();
    insertData();
    compareRowCounts;

    IF (updateSequences) THEN
        doUpdateSequences;
    END IF;

    COMMIT;
END;


/**
* ------------------------------
*/




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
                            updateSequences IN BOOLEAN DEFAULT FALSE)
IS

BEGIN

    logMsg('Beginning installWorkspace (Remote)');

    createCEDSrc(schema2use, passwd2use, db2use);
    fillStageTablesFromCEDSrc(wrkspc);

    doInstallWorkspace(updateSequences);

    -- Because this was a remote install, the CEDSRC database link was
    -- was opened and used.  The TRUE paramter below tells removeCEDSrc to
    -- close it before attempting to remove it.
    removeCEDSrc(TRUE);

    logMsg('End installWorkspace');


    -- handle exceptions
    EXCEPTION
      WHEN CEDSRC_EXIST THEN
        logMsg('The CEDSRC database link exists.  It is possible that another CED_ADMIN procedure is running.');
        RAISE_APPLICATION_ERROR(-20000, 'EXCEPTION: CEDSRC already exists.');
      WHEN ROW_COUNT_MISMATCH THEN
        ROLLBACK;
        logMsg('Row count mismatch.  Changes were rolled back.');
        removeCEDSrc(FALSE);
        RAISE_APPLICATION_ERROR(-20000, 'EXCEPTION: Row Count Mismatch. Rollback occurred');
      WHEN others THEN
        ROLLBACK;
        logMsg('EXCEPTION: Oracle Error '||SQLCODE);
        logMsg('Changes were rolled back.');
        removeCEDSrc(TRUE);
        RAISE;  -- rethrow

END;  -- installWorkspace (Remote)

/**
* ------------------------------
*/


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
                            updateSequences IN BOOLEAN DEFAULT FALSE)
IS

origSchema VARCHAR2(100);
origWrkspc VARCHAR2(100);

BEGIN

    logMsg('Beginning installWorkspace (Local)');

    -- We will be switching to the source schema and workspace, so
    -- first need save original schema workspace in order end up where
    -- we started.
    origSchema := sys_context('USERENV', 'CURRENT_SCHEMA');
    origWrkspc := DBMS_WM.getWorkspace();

    createCEDSrc;
    fillStageTablesFromSchema(wrkspc, schema2use);


    doInstallWorkspace(updateSequences);

    -- Because this was a schema-based install, the CEDSRC database link was
    -- created but never opened.  The FALSE paramter below tells removeCEDSrc not to
    -- try and close it which could throw an exception.
    removeCEDSrc(FALSE);

    logMsg('End installWorkspace');


    -- handle exceptions
    EXCEPTION
      WHEN CEDSRC_EXIST THEN
        logMsg('The CEDSRC database link exists.  It is possible that another CED_ADMIN procedure is running.');
        RAISE_APPLICATION_ERROR(-20000, 'EXCEPTION: CEDSRC already exists.');
      WHEN ROW_COUNT_MISMATCH THEN
        ROLLBACK;
        logMsg('Row count mismatch.  Changes were rolled back.');
        removeCEDSrc(FALSE);
        RAISE_APPLICATION_ERROR(-20000, 'EXCEPTION: Row Count Mismatch. Rollback occurred');
      WHEN others THEN
        ROLLBACK;
        logMsg('EXCEPTION: Oracle Error '||SQLCODE);
        logMsg('Changes were rolled back.');
        removeCEDSrc(FALSE);
        RAISE;  -- rethrow

END;  -- installWorkspace (Local)


/**
* ------------------------------
*/




/**
*   Does the work common to both installWorkspace procedures
* @todo SET TRANSACTION ISOLATION LEVEL SERIALIZABLE or maybe better yet use DBMS_WM.FREEZEWORKSPACE
*/
PROCEDURE doCopyWorkspace
IS

sqlStr VARCHAR2(1000);

BEGIN

    -- We need to prevent hash joins to avoid tickling Oracle bug 6664976
    -- [METALINK ID 557293.1] which is not fixed until 11.1.0.8
    -- sqlStr := 'alter session set "_hash_join_enabled"=FALSE';
    -- EXECUTE IMMEDIATE sqlStr;

    removeData;
    insertData;
    updateData;
    compareRowCounts;
    COMMIT;
END;


/**
* ------------------------------
*/



/**
* Copies data from a local source.
* Selectively deletes unneeded data in the current schema and applies inserts and
* updates as minimally necessary to synchronize with the source schema.  This is generally
* the fastest and most efficient means of copying data between two workspaces.  It is suitable
* for use with both versioned and unversioned schemas
* @param wrkspc The name of the workspace from which to copy
* @param schema2use The name of the schema from which to copy
*/

PROCEDURE copyWorkspace (wrkspc IN VARCHAR2, schema2use IN VARCHAR2, savepoint IN VARCHAR2 default NULL)
IS

origSchema VARCHAR2(100);
origWrkspc VARCHAR2(100);
sqlStr VARCHAR2(1000);

BEGIN


    logMsg('Beginning copyWorkspace (Local)');

    -- We will be switching to the source schema and workspace, so
    -- first need save original schema workspace in order end up where
    -- we started.
    origSchema := sys_context('USERENV', 'CURRENT_SCHEMA');
    origWrkspc := DBMS_WM.getWorkspace();

    createCEDSrc;
    fillStageTablesFromSchema(wrkspc, schema2use, savepoint);

    IF origSchema <> CEDOPS
    THEN
        logMsg('seting _hash_join_enabled to FALSE for bug workaround');
        sqlStr := 'alter session set "_hash_join_enabled"=FALSE';
        EXECUTE IMMEDIATE sqlStr;
    END IF;


    doCopyWorkspace;

    -- Because this was a schema-based install, the CEDSRC database link was
    -- created but never opened.  The FALSE paramter below tells removeCEDSrc not to
    -- try and close it which could throw an exception.
    removeCEDSrc(FALSE);

    logMsg('End copyWorkspace');


    -- handle exceptions
    EXCEPTION
      WHEN CEDSRC_EXIST THEN
        logMsg('The CEDSRC database link exists.  It is possible that another CED_ADMIN procedure is running.');
        RAISE_APPLICATION_ERROR(-20000, 'EXCEPTION: CEDSRC already exists.');
      WHEN ROW_COUNT_MISMATCH THEN
        ROLLBACK;
        logMsg('Row count mismatch.  Changes were rolled back.');
        removeCEDSrc(FALSE);
        RAISE_APPLICATION_ERROR(-20000, 'EXCEPTION: Row Count Mismatch. Rollback occurred');
      WHEN others THEN
        ROLLBACK;
        logMsg('EXCEPTION: Oracle Error '||SQLCODE);
        logMsg('Changes were rolled back.');
        removeCEDSrc(FALSE);
        RAISE;  -- rethrow

END;  -- copyWorkspace (local)


/**
* ------------------------------
*/


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
                            passwd2use IN VARCHAR2, db2use IN VARCHAR2)
IS

origSchema VARCHAR2(100);
origWrkspc VARCHAR2(100);

BEGIN



    logMsg('Beginning copyWorkspace (Remote)');

    createCEDSrc(schema2use, passwd2use, db2use);
    fillStageTablesFromCEDSrc(wrkspc);

    doCopyWorkspace;

    -- Because this was a schema-based install, the CEDSRC database link was
    -- created but never opened.  The FALSE paramter below tells removeCEDSrc not to
    -- try and close it which could throw an exception.
    removeCEDSrc(TRUE);

    logMsg('End copyWorkspace');


    -- handle exceptions
    EXCEPTION
      WHEN CEDSRC_EXIST THEN
        logMsg('The CEDSRC database link exists.  It is possible that another CED_ADMIN procedure is running.');
        RAISE_APPLICATION_ERROR(-20000, 'EXCEPTION: CEDSRC already exists.');
      WHEN ROW_COUNT_MISMATCH THEN
        ROLLBACK;
        logMsg('Row count mismatch.  Changes were rolled back.');
        removeCEDSrc(FALSE);
        RAISE_APPLICATION_ERROR(-20000, 'EXCEPTION: Row Count Mismatch. Rollback occurred');
      WHEN others THEN
        ROLLBACK;
        logMsg('EXCEPTION: Oracle Error '||SQLCODE);
        logMsg('Changes were rolled back.');
        removeCEDSrc(FALSE);
        RAISE;  -- rethrow

END;  -- copyWorkspace (remote)





/**
* ------------------------------
*/


/**
* Copies the contents of schema referenced by the CEDOPS constant into the current schema
* and workspace. A convenience function equivalent to executing copyWorkspace('LIVE',CED_ADMIN.CEDOPS)
*/
PROCEDURE checkoutCEDOPS
IS
BEGIN
    logMsg('Beginning checkoutCEDOPS');
    copyWorkspace('LIVE',CEDOPS);
    logMsg('Finished checkoutCEDOPS');
END;

/**
* ------------------------------
*/


/**
* Copies the contents of schema referenced by the CEDOPS constant and schema to
* the LIVE workspace of schema referenced by the CEDHIST constant and then creates
* a savepoint. If a savepoint name is not provided, then one is sequentially auto-generated.
*
* @param savePoint The name for the savepoint
* @param savePointDescription The description of the savepoint
* @param password2Use The password to connect to OPS CED
* @param database2Use  The SQLNet name of the instance housing OPS CED (e.g. CEDDB01)
* @todo handle/prevent duplicate auto-savepoint name execeptions
*/
PROCEDURE saveCEDOPStoHistory (
                               password2Use IN VARCHAR2 DEFAULT NULL,
                               database2Use IN VARCHAR2 DEFAULT NULL,
                               savePointName IN VARCHAR2 DEFAULT NULL,
                               savePointDescription IN VARCHAR2 DEFAULT NULL)
IS

SPName2Use VARCHAR2(100);
SPDesc2Use VARCHAR2(255);

BEGIN
    logMsg('Beginning saveCEDOPStoHistory');
    -- This really needs to run as cedhist_owner
    IF  sys_context('USERENV', 'CURRENT_SCHEMA') <> CEDHIST
        OR sys_context('USERENV', 'CURRENT_USER') <> CEDHIST THEN
        RAISE_APPLICATION_ERROR(-20000, 'EXCEPTION: Procedure must only be executed as user '||CEDHIST);
    END IF;

    IF  savePointName IS NULL THEN
        -- SPName2Use := 'Auto Savepoint '||TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI');
        SPName2Use := 'AutoSP'|| history_seq.nextval;
        SPDesc2Use := 'Automatically generated savepoint';
    ELSE
        SPName2Use := savePointName;
        SPDesc2Use := savePointDescription;
    END IF;

    -- checkoutCEDOPS;
    copyWorkspace('LIVE', CEDOPS, password2Use, database2Use);

    logMsg('Create Savepoint '||SPName2Use||' - '||SPDesc2Use);
    DBMS_WM.CreateSavepoint('LIVE',SPName2Use, SPDesc2Use);
    logMsg('Finished saveCEDOPStoHistory');
END;


/**
* Copies the contents of schema referenced by the CEDHIST constant and schema to
* the LIVE workspace of schema referenced by the CEDOPS.  
*
* @param savePoint The name of the savepoint from which to restore
*
*/
PROCEDURE restoreCEDOPSFromHistory (savePointName IN VARCHAR2 DEFAULT NULL)
IS

SPName2Use VARCHAR2(100);

BEGIN
    logMsg('Beginning restoreCEDOPSfromHistory');
    -- This really needs to run as cedops_owner
    IF  sys_context('USERENV', 'CURRENT_SCHEMA') <> CEDOPS
        OR sys_context('USERENV', 'CURRENT_USER') <> CEDOPS THEN
        RAISE_APPLICATION_ERROR(-20000, 'EXCEPTION: Procedure must only be executed as user '||CEDOPS);
    END IF;

    IF  savePointName IS NULL THEN
        SPName2Use := 'LATEST';
    ELSE
        SPName2Use := savePointName;
    END IF;
    logMsg('Restore Savepoint '||SPName2Use);

    copyworkspace('LIVE',CEDHIST, SPName2Use);

    logMsg('restoreCEDOPSfromHistory');
END;




/**
* ------------------------------
*/




/**
* Updates sequences to start after the max current val for
* each sequence that was stored previously into t_user_sequences
*
* To enable creation of elements in a newly copied database, the sequences in the new
* copy must be updated to start at a higher number than where the source database left off.
* This procedures assumes the pre-existence of the t_user_sequences temporary table.
*
*/

PROCEDURE doUpdateSequences
IS

TYPE updCursorTyp IS REF CURSOR;
updCursor  updCursorTyp;
r_user_sequences  user_sequences%ROWTYPE;
sqlStr VARCHAR2(1000);
nextNum INTEGER;

BEGIN
    logMsg('Recreating sequences to update nextvals... ');

    sqlStr :=  'SELECT * FROM t_user_sequences where sequence_name <> ''LOG_ID'' ';
    Open updCursor for sqlStr;

    LOOP
         FETCH updCursor into r_user_sequences;
         EXIT WHEN updCursor%NOTFOUND;
         logMsg('Updating... '||r_user_sequences.sequence_name);
         sqlStr := 'drop sequence '||r_user_sequences.sequence_name;
         EXECUTE IMMEDIATE sqlStr;
         logMsg('Dropped... '||r_user_sequences.sequence_name);
         nextNum :=  r_user_sequences.last_number + r_user_sequences.increment_by;
         sqlStr := 'create sequence '||r_user_sequences.sequence_name||' start with '||nextNum||
                   'increment by '||r_user_sequences.increment_by;
         --logMsg(sqlStr);
         EXECUTE IMMEDIATE sqlStr;
         logMsg('Recreated... '||r_user_sequences.sequence_name);
     END LOOP;
     CLOSE updCursor;

     logMsg('Done recreating sequences.');

END;  -- updateSequences;


/**
* ------------------------------
*/



/**
* Creates CEDSRC database link using the provided connection parameters.
*
* @param schema2use The name of the schema from which to copy
* @param passwd2use The password to connect to schema2use
* @param db2use The service identifier (ceddb01, cedtestm etc.) of the source database
* @throws CED_SRC_EXIST if the dblink already exists implying an active lock.
*/
PROCEDURE createCEDSrc (schema2use IN VARCHAR2, passwd2use IN VARCHAR2, db2use IN VARCHAR2)
IS

sqlStr VARCHAR2(1000);


BEGIN

    sqlStr := 'create database link CEDSRC connect to '||schema2use
              ||' identified by "'||passwd2use
              ||'" using '''||db2use||''' ';

    logMsg ('database link cedsrc created using '||schema2use||' at '||db2use);
    EXECUTE IMMEDIATE  sqlStr;

    EXCEPTION
        WHEN OTHERS THEN
               logMsg('EXCEPTION: Database link creation failed with Oracle error '||SQLCODE);
               RAISE CEDSRC_EXIST;       -- Throws a custom exception so that we know
                                         -- not to remove cedsrc as it was preexisting
END;  -- createCEDSrc

/**
* ------------------------------
*/


/**
* Creates a database to nowhere that to serve as a lock.
* @throws CED_SRC_EXIST if the dblink already exists implying an active lock.
*/
PROCEDURE createCEDSrc
IS

sqlStr VARCHAR2(1000);


BEGIN

    sqlStr := 'create database link CEDSRC';

    logMsg (sqlStr);

    EXECUTE IMMEDIATE  sqlStr;

    EXCEPTION
        WHEN OTHERS THEN
               logMsg('EXCEPTION: Database link creation failed with Oracle error '||SQLCODE);
               RAISE CEDSRC_EXIST;       -- Throws a custom exception so that we know
                                         -- not to remove cedsrc as it was preexisting

END;  -- createCEDSrc

/**
* ------------------------------
*/


/**
* Closes and drops the database link name CEDSRC.
* Failure to remove the link will prevent future executions of install or
* copy procedures in this package.
*
*/

PROCEDURE removeCEDSrc(closeDBLink IN BOOLEAN DEFAULT TRUE)
IS

sqlStr VARCHAR2(1000);

BEGIN

   IF closeDBLink
   THEN
    sqlStr := 'alter session close database link CEDSRC';
    EXECUTE IMMEDIATE  sqlStr;
   END IF;

   sqlStr := 'drop database link CEDSRC';
   EXECUTE IMMEDIATE  sqlStr;

   -- Best to leave them around for next time?
   -- dropStageTables;

END;  -- removeCEDSrc


/**
* ------------------------------
*/


/**
* Brute force deletion of all data in the tables.  No attempt is made to limit what gets
* deleted.  It's all thrown out.
*/
PROCEDURE purgeData
IS

sqlStr VARCHAR2(1000);


BEGIN

    logMsg('Beginning purgeData installWorkspace at .... '||sysdate);

    -- Deleting from cmpnt_type can be problematic because of the parent_cmpnt_type_id
    -- hierarchy.  Since we're deleting everything anyhow, setting that to null here
    -- prevents us having to be careful about deletion order later.
    UPDATE cmpnt_type SET parent_cmpnt_type_id = NULL;

    -- Note that looping through all tables may be a tad redundant as the
    -- cascade on delete will purge many of the sub-tables.
    FOR n in 1 .. ced_tables.count
    LOOP
      sqlStr := 'delete from '||ced_tables(n);
      --logMsg(sqlStr);
      EXECUTE IMMEDIATE  sqlStr;
      logMsg('deleted '||SQL%ROWCOUNT||' rows from '||ced_tables(n));
    END LOOP;

END;  -- purgeData


/**
* ------------------------------
*/

/**
* Compares number of rows in each table between the temp tables and current schema.
* It is run at the end of copy/install methods as a sanity check.
*
* @param throwOnMismatch When set to FALSE, will suppress throwing of a ROW_COUNT_MISMATCH exception.
* @throws ROW_COUNT_MISMATCH if number of rows in schema doesn't match rows in stage tables.
*/
PROCEDURE compareRowCounts (throwOnMismatch BOOLEAN DEFAULT TRUE)
IS

sqlStr VARCHAR2(1000);


count1 INTEGER;
count2 INTEGER;

BEGIN

    logMsg('Beginning compareRowCounts .... ');

    FOR n in 1 .. ced_tables.count
    LOOP
      -- The temp tables
      sqlStr := 'select count(*) from t_'||ced_tables(n);
      EXECUTE IMMEDIATE sqlStr into count1;

      -- The newly update tables
      sqlStr := 'select count(*) from '||ced_tables(n);
      EXECUTE IMMEDIATE sqlStr into count2;

      IF count1 = count2 THEN
        logMsg('MATCH: '||ced_tables(n)||'...SRC = '||count1||' DEST = '||count2);
      ELSE
        logMsg('NO MATCH: '||ced_tables(n)||'...SRC = '||count1||' DEST = '||count2);
        IF throwOnMismatch THEN
            RAISE ROW_COUNT_MISMATCH;
        END IF;
      END IF;

    END LOOP;

END;  -- compareRowCounts


/**
* ------------------------------
*/



/**
* Checks whether sequence.currval is available.  Traps the exception that is
* thrown by trying to reference non-existent currval.  If currval is not available
* this function calls nextval to make it available.
*
*/
FUNCTION check_event_id_currval RETURN INTEGER
IS
-- ORA-08002: sequence EVENT_ID.CURRVAL is not yet defined in this session
currval_not_avail EXCEPTION;
PRAGMA EXCEPTION_INIT (currval_not_avail, -8002);
x number;
begin
select event_id.currval into X from dual;
return X;
exception
when currval_not_avail
then return 0;
end;



/**
* Return a string that identifies the current database instance
* as a particular CED deployment name (ced, led, etc.)
*/
FUNCTION currentDeployment RETURN VARCHAR2
IS
    currentInstance varchar2(100);
begin
  currentInstance := sys_context('USERENV', 'DB_NAME');
  CASE upper(currentInstance)
    WHEN 'CEDTEST' THEN RETURN 'dvl';
    WHEN 'CEDDB01' THEN RETURN 'ced';
    WHEN 'LEDDB01' THEN RETURN 'led';
    WHEN 'UEDDB01' THEN RETURN 'ued';
    WHEN 'JEDDB01' THEN RETURN 'jed';
    ELSE RETURN NULL;
  END CASE;
END;




/**
* Begins a History Event by setting package variable eventID to non-null if suppressHistory
* is not set to TRUE.
*/
PROCEDURE beginHistEvent
IS

l_seq NUMBER;

BEGIN

  l_seq := check_event_id_currval;
  IF l_seq > 0 THEN
    RETURN;
  END IF;

  IF suppressHistory = FALSE
  THEN
      -- logMsg('Beginning event');
      SELECT event_id.nextval INTO l_seq FROM dual;
      logMsg('Begin event_id '||l_seq);
  END IF;
END;



/**
* Ends a notifyEvent by setting package variable eventID to null.
* @param sessionEnding Set to true to prevent grabbing the next eventid,
*        For example if about to terminate session.
*/
PROCEDURE endHistEvent (sessionEnding BOOLEAN DEFAULT FALSE)
IS

idStr VARCHAR2(100);
deployment VARCHAR2(100);
retVal INTEGER;
l_seq INTEGER;

BEGIN
  --logMsg('Howdy from endHistEvent');
  l_seq := check_event_id_currval;
  IF l_seq > 0
  THEN
    idStr := to_char(event_id.currval);
    deployment := to_char(currentDeployment);

    logMsg('Ending event id '||idStr);

    IF eventAck = 0
    THEN
        logMsg('calling ced_notify('||deployment||', '||idStr||')');
        retVal := ced_notify(deployment, idStr);
        IF retVal > 0
        THEN
          logMsg('ced_notify error code '||to_char(retVal));
        END IF;
    END IF;

    IF sessionEnding <> TRUE
    THEN
        -- End usage of current sequence by selecting next val.
        SELECT event_id.nextval INTO l_seq FROM dual;
    END IF;
  ELSE
    logMsg('No event to end');
  END IF;
END;




/**
* Enables ced_notification events (the default)
*/
PROCEDURE enableCEDNotify
IS
BEGIN
  eventACK := 0;
END;


/**
* Disables ced_notification events
*/
PROCEDURE disableCEDNotify
IS
BEGIN
  eventACK := 1;
END;





/**
* Puts a row into the hist_cmpnt_prop_val table.
*
* @param actionFlag (I|U|D)
* @param cmpntID cmpnt_id
* @param propID cmpnt_type_prop_id
* @param dim1
* @param dim2
* @param oldValue
* @param newValue
*/
PROCEDURE doHistCmpntPropVal(tableName IN VARCHAR2, actionFlag IN CHAR,
                        cmpntID IN INTEGER, propID in INTEGER,
                        dim1 IN INTEGER DEFAULT NULL, dim2 IN INTEGER DEFAULT NULL,
                        oldValue in VARCHAR2 DEFAULT NULL, newValue in VARCHAR2 DEFAULT NULL)
IS

currentSchema VARCHAR2(30);
currentWorkspace VARCHAR2(30);



BEGIN

    beginHistEvent;

    -- logMsg('HIST_CMPNT_PROP_VAL: '||tablename||', '||actionFlag||', '||cmpntID||', '||propID||', '||oldValue||', '||newValue);

    IF cmpntID IS NOT NULL  AND propID IS NOT NULL
    THEN
        currentSchema := sys_context('USERENV', 'CURRENT_SCHEMA');
        currentWorkspace := DBMS_WM.getWorkspace();
        insert into hist_cmpnt_prop_val
          (event_id, owner, workspace, table_name, cmpnt_id, cmpnt_type_prop_id,
           action_flag, event_date, dim1, dim2, old_value, new_value, ack)
        values
          (event_id.currval, currentSchema, currentWorkspace, tableName, cmpntID, propID,
           actionFlag, sysdate, dim1, dim2, oldValue, newValue, eventACK);
    ELSE
         logMsg('HIST_CMPNT_PROP_VAL: '||tablename||', '||actionFlag||', '||cmpntID||', '||propID||', '||oldValue||', '||newValue);
    END IF;

END;



/**
* Puts a row into the hist_cmpnt_prop table.
*
* @param actionFlag (I|U|D)
* @param cmpntID cmpnt_id
* @param propID cmpnt_type_prop_id
* @param oldComments
* @param newComments
* @param oldSetBy
* @param newSetBy
* @param oldModifyDate
* @param newModifyDate
*/
PROCEDURE doHistCmpntProp(actionFlag IN CHAR,
                        cmpntID IN INTEGER, propID in INTEGER,
                        oldComments IN VARCHAR2 DEFAULT NULL, newComments IN VARCHAR2 DEFAULT NULL,
                        oldSetBy IN VARCHAR2 DEFAULT NULL, newSetBy IN VARCHAR2 DEFAULT NULL,
                        oldModifyDate in TIMESTAMP DEFAULT NULL, newModifyDate in TIMESTAMP DEFAULT NULL)
IS

currentSchema VARCHAR2(30);
currentWorkspace VARCHAR2(30);



BEGIN

    beginHistEvent;

    IF cmpntID IS NOT NULL  AND propID IS NOT NULL
    THEN
    currentSchema := sys_context('USERENV', 'CURRENT_SCHEMA');
    currentWorkspace := DBMS_WM.getWorkspace();
    insert into hist_cmpnt_prop
      (event_id, owner, workspace, table_name, cmpnt_id, cmpnt_type_prop_id,
       action_flag, event_date, old_comments, new_comments, old_set_by, new_set_by,
       old_modify_date, new_modify_date, ack)
    values
      (event_id.currval, currentSchema, currentWorkspace, 'CMPNT_PROP', cmpntID, propID,
       actionFlag, sysdate, oldComments, newComments, oldSetBy, newSetBy,
       oldModifyDate, newModifyDate, eventACK);

    ELSE
        logMsg('HIST_CMPNT_PROP_VAL Error: '||actionFlag||', '||cmpntID||', '||propID);
    END IF;

END;


/**
* Puts a row into the hist_cmpnt_prop table.
*
* @param actionFlag (I|U|D)
* @param cmpntID cmpnt_id
* @param oldComments
* @param newComments
* @param oldSetBy
* @param newSetBy
* @param oldModifyDate
* @param newModifyDate

*/
PROCEDURE doHistCmpnt ( actionFlag IN CHAR,
                        cmpntID IN INTEGER,
                        oldName IN VARCHAR2 DEFAULT NULL, newName IN VARCHAR2 DEFAULT NULL,
                        oldTypeId IN INTEGER DEFAULT NULL, newTypeId IN INTEGER DEFAULT NULL)
IS

currentSchema VARCHAR2(30);
currentWorkspace VARCHAR2(30);



BEGIN

    beginHistEvent;


    IF cmpntID IS NOT NULL
    THEN
        -- logMsg('HIST_CMPNT: '||cmpntID||', '||newName);

        currentSchema := sys_context('USERENV', 'CURRENT_SCHEMA');
        currentWorkspace := DBMS_WM.getWorkspace();
        insert into hist_cmpnt
          (event_id, owner, workspace, table_name, cmpnt_id,
           action_flag, event_date, old_name, new_name, old_cmpnt_type_id, new_cmpnt_type_id, ack)
        values
          (event_id.currval, currentSchema, currentWorkspace, 'CMPNT', cmpntID,
           actionFlag, sysdate, oldName, newName, oldTypeId, newTypeId, eventACK);
    ELSE
        logMsg('HIST_CMPNT Error: NULL cmpnt_id given');
    END IF;
END;





/**
* Removes rows from schema tables that don't exist in corresponding t_* staging tables.
*
* NOT IN can be just as efficient as NOT EXISTS -- many orders of magnitude BETTER even --
* if an "anti-join" can be used (if the subquery is known to not return nulls)
*/
PROCEDURE removeData
IS

sqlStr VARCHAR2(1000);
ok2proceed BOOLEAN := false;
tally INTEGER;


BEGIN


    logMsg(sys_context('USERENV', 'CURRENT_SCHEMA'));
    logMsg(DBMS_WM.getWorkspace());


    /*
     Zones
    */
    -- Removing zones will cascde to segments and zone_links
    sqlStr := 'delete from zones
               where zone_id not in
                (select zone_id from t_zones)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('zones removed.... '||SQL%ROWCOUNT);

    -- Just in case no cascading happened above
    sqlStr := 'delete from zone_links
               where zone_links_id not in
                (select zone_links_id from t_zone_links)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('zones_links removed.... '||SQL%ROWCOUNT);

    sqlStr := 'delete from segments
               where segment_id not in
                (select segment_id from t_segments)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('segments removed.... '||SQL%ROWCOUNT);



    /*
     Cmpnt
    */
    -- Clean out the fk_cmpnt values table first b/c it could trip cmpnt deletes
    sqlStr := 'delete from cmpnt_prop_fk_cmpnt
               where value not in
                (select cmpnt_id from t_cmpnt)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('fk_cmpnt values removed.... '||SQL%ROWCOUNT);

    -- Removing elements from cmpnt should cascde to their properties
    -- in the cmpnt_prop and then onto the cmpnt_prop_* tables.
    sqlStr := 'delete from cmpnt
               where cmpnt_id not in
                (select cmpnt_id from t_cmpnt)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt removed.... '||SQL%ROWCOUNT);

    -- This extra SQL catches cmpnt that may have a new cmpnt_type_id.
    -- which will get added back later.  This is because type
    -- deletes don't cascade to cmpnt.
    sqlStr := 'delete from cmpnt
               where cmpnt_type_id not in
                (select cmpnt_type_id from t_cmpnt_type)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt removed.... '||SQL%ROWCOUNT);




    /*
     Catalog tables
    */

    -- Removing types will cascade to their property defs
    -- but we have to proceed iteratively because the table
    -- has FK to itself via the parent_cmpnt_type_id column.
    tally := 0;
    sqlStr := 'delete from cmpnt_type a
                where cmpnt_type_id not in
                    (select cmpnt_type_id from t_cmpnt_type)
                and not exists
                    (select parent_cmpnt_type_id from cmpnt_type
                     where parent_cmpnt_type_id = a.cmpnt_type_id)';
    WHILE ok2proceed = false
    LOOP
        tally := tally + 1;
        EXECUTE IMMEDIATE  sqlStr;
        logMsg('cmpnt_type removed.... '||SQL%ROWCOUNT);
        IF SQL%ROWCOUNT = 0 OR tally > 100 THEN
            ok2proceed := true;
        END IF;
    END LOOP;


    

    -- Removing properites should cascade too
    sqlStr := 'delete from cmpnt_type_prop
               where cmpnt_type_prop_id not in
                (select cmpnt_type_prop_id from t_cmpnt_type_prop)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_type_prop removed.... '||SQL%ROWCOUNT);

    -- Because the cmpnt_type_prop_mix table was added at a point
    -- where we already had years of history, we couldn't add a 
    -- foreign key constraint in the history schema.  Therefore we
    -- can't count on cascading delete from cmpnt_type_prop, but
    -- must explicitly hand lethe table here. 
        sqlStr := 'delete from cmpnt_type_prop_mix
               where (cmpnt_type_prop_id, cmpnt_type_id, indx) not in
                (select cmpnt_type_prop_id, cmpnt_type_id, indx from t_cmpnt_type_prop_mix)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_type_prop_mix removed.... '||SQL%ROWCOUNT);


    -- Need to temporarily "unset" (set to 0) the category_id for categories
    -- That will be deleted.
    sqlStr := 'update cmpnt_type_prop
                set category_id = 0
               where
                category_id not in ( select category_id from t_cmpnt_type_prop_cats)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('category_ids temporarily set to 0.... '||SQL%ROWCOUNT);



    sqlStr :=
       'delete from cmpnt_type_prop_dom
        where (cmpnt_type_prop_id, cmpnt_type_id) not in
            (select cmpnt_type_prop_id, cmpnt_type_id from t_cmpnt_type_prop_dom)';

    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_type_prop_dom removed.... '||SQL%ROWCOUNT);

    sqlStr :=
       'delete from cmpnt_type_prop_dim
        where (cmpnt_type_prop_id, cmpnt_type_id) not in
            (select cmpnt_type_prop_id, cmpnt_type_id from t_cmpnt_type_prop_dim)';

    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_type_prop_dim removed.... '||SQL%ROWCOUNT);


    sqlStr :=
       'delete from cmpnt_type_prop_def
        where (cmpnt_type_prop_id, cmpnt_type_id) not in
            (select cmpnt_type_prop_id, cmpnt_type_id from t_cmpnt_type_prop_def)';

    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_type_prop_def removed.... '||SQL%ROWCOUNT);


    sqlStr :=
       'delete from cmpnt_type_prop_req
        where (cmpnt_type_prop_id, cmpnt_type_id) not in
            (select cmpnt_type_prop_id, cmpnt_type_id from t_cmpnt_type_prop_req)';

    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_type_prop_req removed.... '||SQL%ROWCOUNT);


    sqlStr :=
       'delete from cmpnt_type_prop_cats
        where category_id not in
            (select category_id from t_cmpnt_type_prop_cats)';

    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_type_prop_cats removed.... '||SQL%ROWCOUNT);


    sqlStr :=
        'delete from category_sets
         where set_id not in
            (select set_id from t_category_sets)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('category_sets removed.... '||SQL%ROWCOUNT);



    /*
     Inventory tables
    */

    FOR n in 1 .. value_tables.count
    LOOP
     sqlStr :=
         'delete from '||value_tables(n)||
         ' where
                  (cmpnt_id, cmpnt_type_prop_id, dim1, dim2)
          not in
           (select cmpnt_id, cmpnt_type_prop_id, dim1, dim2
          from t_'||value_tables(n)||')';

        --logMsg(sqlStr);
        EXECUTE IMMEDIATE  sqlStr;
        logMsg(value_tables(n)||' rows removed.... '||SQL%ROWCOUNT);

    END LOOP;

    sqlStr :=
        'delete from cmpnt_prop
         where (cmpnt_id, cmpnt_type_prop_id) not in
            (select cmpnt_id, cmpnt_type_prop_id from t_cmpnt_prop)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_prop removed.... '||SQL%ROWCOUNT);



    /*
     Owner tables
    */

    sqlStr :=
        'delete from cmpnt_owners
         where (cmpnt_id, owner) not in
            (select cmpnt_id, owner from t_cmpnt_owners)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_owners removed.... '||SQL%ROWCOUNT);



    sqlStr :=
        'delete from cmpnt_type_owners
         where (cmpnt_type_id, owner) not in
            (select cmpnt_type_id, owner from t_cmpnt_type_owners)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_type_owners removed.... '||SQL%ROWCOUNT);

    sqlStr :=
        'delete from cmpnt_type_prop_owners
         where (cmpnt_type_prop_id, owner) not in
            (select cmpnt_type_prop_id, owner from t_cmpnt_type_prop_owners)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_type_prop_owners removed.... '||SQL%ROWCOUNT);

END;  -- removeData


/**
* ------------------------------
*/


/**
* Inserts rows into schema CED tables that exist in t_* staging tables, but don't currently exist
* in current schema tables.
*/

PROCEDURE insertData
IS

sqlStr VARCHAR2(1000);
tally INTEGER;
ok2proceed BOOLEAN := FALSE;

BEGIN

    -- Catalogy bits
    logMsg('Beginning insertData');


    -- Especially when inserting into versioned tables, it's
    -- important to insert parent keys before child keys in
    -- self referencing tables.
    tally := 0;
    sqlStr :=
        'insert into cmpnt_type
            (cmpnt_type_id, parent_cmpnt_type_id, name, description, is_abstract, name_limit )
        select
            cmpnt_type_id, parent_cmpnt_type_id, name, description, is_abstract, name_limit
        from t_cmpnt_type
        where
            cmpnt_type_id  not in ( select cmpnt_type_id from cmpnt_type )
            and(
                parent_cmpnt_type_id in ( select cmpnt_type_id from cmpnt_type )
                OR
                parent_cmpnt_type_id is null)';
    -- logMsg(sqlStr);
    WHILE ok2proceed = false
    LOOP
        tally := tally + 1;
        EXECUTE IMMEDIATE  sqlStr;
        IF SQL%ROWCOUNT = 0 OR tally > 500 THEN
            ok2proceed := true;
        END IF;
        logMsg('cmpnt_type added.... '||SQL%ROWCOUNT);
    END LOOP;


    sqlStr :=
    'insert into category_sets
        (set_id, name, ordering)
    select
        set_id, name, ordering
    from t_category_sets
    where set_id not in ( select set_id from category_sets)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('category_sets added.... '||SQL%ROWCOUNT);



    sqlStr :=
    'insert into cmpnt_type_prop_cats
        (category_id, set_id, category, ordering)
    select
         category_id, set_id, category, ordering
    from t_cmpnt_type_prop_cats
    where category_id not in ( select category_id from cmpnt_type_prop_cats)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt_type_prop_cats added.... '||SQL%ROWCOUNT);


    sqlStr :=
    'insert into cmpnt_type_prop
        (cmpnt_type_prop_id, cmpnt_type_id, name, type, units, description, live_edit, category_id, multipass)
    select cmpnt_type_prop_id, cmpnt_type_id, name, type, units, description, live_edit, category_id, multipass
    from t_cmpnt_type_prop
        where cmpnt_type_prop_id not in ( select cmpnt_type_prop_id from cmpnt_type_prop)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt_type_prop added.... '||SQL%ROWCOUNT);


    sqlStr :=
    'insert into cmpnt_type_prop_dom
        (cmpnt_type_prop_id, cmpnt_type_id, domain)
    select cmpnt_type_prop_id, cmpnt_type_id, domain
    from t_cmpnt_type_prop_dom
        where (cmpnt_type_prop_id, cmpnt_type_id)
        not in  ( select cmpnt_type_prop_id, cmpnt_type_id from cmpnt_type_prop_dom)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt_type_prop_dom added.... '||SQL%ROWCOUNT);

       sqlStr :=
    'insert into cmpnt_type_prop_dim
        (cmpnt_type_prop_id, cmpnt_type_id, dim1_max, dim2_max)
    select cmpnt_type_prop_id, cmpnt_type_id, dim1_max, dim2_max
    from t_cmpnt_type_prop_dim
        where (cmpnt_type_prop_id, cmpnt_type_id)
        not in  ( select cmpnt_type_prop_id, cmpnt_type_id from cmpnt_type_prop_dim)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt_type_prop_dim added.... '||SQL%ROWCOUNT);


    sqlStr :=
    'insert into cmpnt_type_prop_def
        (cmpnt_type_prop_id, cmpnt_type_id, value_default)
    select cmpnt_type_prop_id, cmpnt_type_id, value_default
    from t_cmpnt_type_prop_def
        where (cmpnt_type_prop_id, cmpnt_type_id)
        not in  ( select cmpnt_type_prop_id, cmpnt_type_id from cmpnt_type_prop_def)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt_type_prop_def added.... '||SQL%ROWCOUNT);


     sqlStr :=
    'insert into cmpnt_type_prop_req
         (cmpnt_type_prop_id, cmpnt_type_id, required)
     select cmpnt_type_prop_id, cmpnt_type_id, required
     from t_cmpnt_type_prop_req
        where (cmpnt_type_prop_id, cmpnt_type_id)
        not in  ( select cmpnt_type_prop_id, cmpnt_type_id from cmpnt_type_prop_req)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt_type_prop_req added.... '||SQL%ROWCOUNT);


     sqlStr :=
    'insert into cmpnt_type_prop_mix
         (cmpnt_type_prop_id, cmpnt_type_id, indx, type, label, domain)
     select cmpnt_type_prop_id, cmpnt_type_id, indx, type, label, domain
     from t_cmpnt_type_prop_mix
        where (cmpnt_type_prop_id, cmpnt_type_id, indx)
        not in  ( select cmpnt_type_prop_id, cmpnt_type_id, indx from cmpnt_type_prop_mix)';
    EXECUTE IMMEDIATE  sqlStr;
    logMsg('cmpnt_type_prop_mix added.... '||SQL%ROWCOUNT);
    
    

    -- Inventory bits

    sqlStr :=
    'insert into cmpnt
        (cmpnt_id, cmpnt_type_id, name)
    select cmpnt_id, cmpnt_type_id, name
        from t_cmpnt
        where cmpnt_id not in (select cmpnt_id from cmpnt)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt added.... '||SQL%ROWCOUNT);


    sqlStr :=
    'insert into cmpnt_prop
        (cmpnt_id, cmpnt_type_prop_id, modify_date, set_by, comments)
    select cmpnt_id, cmpnt_type_prop_id, modify_date, set_by, comments from t_cmpnt_prop
        where (cmpnt_id, cmpnt_type_prop_id) not in (
            select cmpnt_id, cmpnt_type_prop_id from cmpnt_prop)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt_prop added.... '||SQL%ROWCOUNT);


    -- The BLOB value table will not be handled in this loop, but dealt with
    -- separately afterwards.
    FOR n in 1 .. value_tables.count
    LOOP
       IF value_tables(n) <> 'CMPNT_PROP_BLOB' THEN
            -- value_id will go away one day
           sqlStr :=
            'insert into '||value_tables(n)||
            ' (cmpnt_id, cmpnt_type_prop_id, dim1, dim2, value, value_id)'||
            ' select cmpnt_id, cmpnt_type_prop_id, dim1, dim2, value, value_id from t_'||value_tables(n)||
            ' where (cmpnt_id, cmpnt_type_prop_id, dim1, dim2) not in '||
            '   (select cmpnt_id, cmpnt_type_prop_id, dim1, dim2 from ' ||value_tables(n)||')';
          EXECUTE IMMEDIATE sqlStr;

          logMsg(value_tables(n)||' added.... '||SQL%ROWCOUNT);
        END IF;
    END LOOP;


    sqlStr :=
    'insert into cmpnt_prop_blob
        (cmpnt_id, cmpnt_type_prop_id, dim1, dim2, mime_type, value, value_id)
    select cmpnt_id, cmpnt_type_prop_id, dim1, dim2, mime_type, value, value_id from t_cmpnt_prop_blob
        where (cmpnt_id, cmpnt_type_prop_id, dim1, dim2) not in
            (select cmpnt_id, cmpnt_type_prop_id, dim1, dim2 from cmpnt_prop_blob)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt_prop_blob added.... '||SQL%ROWCOUNT);


    -- Owner tables

    sqlStr :=
    'insert into cmpnt_type_owners
        (cmpnt_type_id, owner)
    select cmpnt_type_id, owner from t_cmpnt_type_owners
        where  (cmpnt_type_id, owner) not in ( select cmpnt_type_id, owner from cmpnt_type_owners )';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt_type_owners added.... '||SQL%ROWCOUNT);


    sqlStr :=
    'insert into cmpnt_type_prop_owners
        (cmpnt_type_prop_id, owner)
    select cmpnt_type_prop_id, owner from t_cmpnt_type_prop_owners
        where  (cmpnt_type_prop_id, owner) not in ( select cmpnt_type_prop_id, owner from cmpnt_type_prop_owners )';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt_type_prop_owners added.... '||SQL%ROWCOUNT);

    sqlStr :=
    'insert into cmpnt_owners
        (cmpnt_id, owner)
    select cmpnt_id, owner from t_cmpnt_owners
        where  (cmpnt_id, owner) not in ( select cmpnt_id, owner from cmpnt_owners )';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('cmpnt_owners added.... '||SQL%ROWCOUNT);

    -- Zone stuff

    sqlStr :=
    'insert into zones
        (zone_id, name, description, is_multi, contiguous)
    select zone_id, name, description, is_multi, contiguous from t_zones
        where zone_id not in ( select zone_id from zones)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('zones added.... '||SQL%ROWCOUNT);


    sqlStr :=
    'insert into zone_links
        (zone_links_id, zone_id, parent_zone_id)
    select zone_links_id, zone_id, parent_zone_id from t_zone_links
        where zone_links_id not in ( select zone_links_id from zone_links )';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('zone_links added.... '||SQL%ROWCOUNT);


    sqlStr :=
    'insert into segments
        (segment_id, zone_id, mask, start_cmpnt, start_pass, end_cmpnt, end_pass)
    select segment_id, zone_id, mask, start_cmpnt, start_pass, end_cmpnt, end_pass from t_segments
        where segment_id not in (select segment_id from segments)';
    EXECUTE IMMEDIATE sqlStr;
    logMsg('segments added.... '||SQL%ROWCOUNT);


    EXCEPTION
        WHEN OTHERS THEN
               ROLLBACK;
               logMsg('EXCEPTION: Oracle Error '||SQLCODE);
               RAISE;       -- Re-throws

END;  -- insertData


/**
* ------------------------------
*/


/**
* Update the non-key columns of each local table to match the values of the corresponding
* columns in the staged t_* temp tables
*
*/

PROCEDURE updateData
IS

    ok2proceed BOOLEAN := false;
    tally INTEGER;
    sqlStr VARCHAR2(1000);

    TYPE updCursorTyp IS REF CURSOR;
    updCursor  updCursorTyp;


    -- The general-purpose updCursor will have to be fetched into
    -- a different %ROWTYPE structure for each table
    r_cmpnt_type                cmpnt_type%ROWTYPE;
    r_cmpnt                     cmpnt%ROWTYPE;
    r_cmpnt_type_prop           cmpnt_type_prop%ROWTYPE;
    r_cmpnt_type_prop_dom       cmpnt_type_prop_dom%ROWTYPE;
    r_cmpnt_type_prop_dim       cmpnt_type_prop_dim%ROWTYPE;
    r_cmpnt_type_prop_def       cmpnt_type_prop_def%ROWTYPE;
    r_cmpnt_type_prop_req       cmpnt_type_prop_req%ROWTYPE;
    r_cmpnt_type_prop_mix       cmpnt_type_prop_mix%ROWTYPE;
    r_cmpnt_type_prop_cats      cmpnt_type_prop_cats%ROWTYPE;
    r_category_sets             category_sets%ROWTYPE;
    r_zones                     zones%ROWTYPE;
    r_zone_links                zone_links%ROWTYPE;
    r_segments                  segments%ROWTYPE;
    r_cmpnt_prop                cmpnt_prop%ROWTYPE;
    r_cmpnt_prop_fk_cmpnt       cmpnt_prop_fk_cmpnt%ROWTYPE;
    r_cmpnt_prop_bool           cmpnt_prop_bool%ROWTYPE;
    r_cmpnt_prop_blob           cmpnt_prop_blob%ROWTYPE;
    r_cmpnt_prop_integer        cmpnt_prop_integer%ROWTYPE;
    r_cmpnt_prop_float          cmpnt_prop_float%ROWTYPE;
    r_cmpnt_prop_string         cmpnt_prop_string%ROWTYPE;
    r_cmpnt_prop_date           cmpnt_prop_date%ROWTYPE;

    -- Are the following actually needed?
    -- There are no non-pk columns to update, so
    -- deletes and inserts should have sufficed.
    r_cmpnt_type_prop_owners    cmpnt_type_prop_owners%ROWTYPE;
    r_cmpnt_type_owners         cmpnt_type_owners%ROWTYPE;
    r_cmpnt_owners              cmpnt_owners%ROWTYPE;

    -- %ROWTYPE is problematic when there's a blob, so
    -- we need independent variables for the key columns
    -- instead.
    t_cmpnt_id                 cmpnt_prop_blob.cmpnt_id%TYPE;
    t_cmpnt_type_prop_id       cmpnt_prop_blob.cmpnt_type_prop_id%TYPE;
    t_dim1                     cmpnt_prop_blob.dim1%TYPE;
    t_dim2                     cmpnt_prop_blob.dim2%TYPE;
    t_value                    cmpnt_prop_blob.value%TYPE;
    t_value_id                 cmpnt_prop_blob.value_id%TYPE;
    t_value_md5                cmpnt_prop_blob.value_md5%TYPE;
    t_mime_type                cmpnt_prop_blob.mime_type%TYPE;


    -- We can't update blob columns like we do other columns


BEGIN

    /*
      Textpad regex to turn table@CEDSRC into t_table
      -----------------------------------------------
      Find what: \([a-z_]+\)@CEDSRC
      Replace with: t_\1
    */

    -- CMPNT_TYPE

    sqlStr :=  '
            select b.*
            from cmpnt_type a, t_cmpnt_type b
            where
                a.cmpnt_type_id = b.cmpnt_type_id and
                (
                    a.name <> b.name or
                    a.parent_cmpnt_type_id <> b.parent_cmpnt_type_id or
                    nvl(a.name_limit, -1) <> nvl(b.name_limit, -1) or
                    nvl(a.description,-1) <> nvl(b.description,-1) or
                    nvl(a.is_abstract, -1) <> nvl(b.is_abstract, -1)
                )';

    Open updCursor for sqlStr;
    tally := 0;
     LOOP
         FETCH updCursor into r_cmpnt_type;
         EXIT WHEN updCursor%NOTFOUND;
         logMsg('Updating... '||r_cmpnt_type.name);
         UPDATE cmpnt_type
             SET
               parent_cmpnt_type_id = r_cmpnt_type.parent_cmpnt_type_id,
               name                 = r_cmpnt_type.name,
               name_limit           = r_cmpnt_type.name_limit,
               description          = r_cmpnt_type.description,
               is_abstract          = r_cmpnt_type.is_abstract
             WHERE
               cmpnt_type_id = r_cmpnt_type.cmpnt_type_id;
         tally := tally + 1;
     END LOOP;
     CLOSE updCursor;
     logMsg('cmpnt_type rows updated... '||tally);



    -- CMPNT
    sqlStr :=  '
        select b.*
        from cmpnt a, t_cmpnt b
        where
            a.cmpnt_id = b.cmpnt_id and
            (
                a.name <> b.name or
                a.cmpnt_type_id <> b.cmpnt_type_id
            )';

    Open updCursor for sqlStr;

    tally := 0;
     LOOP
         FETCH updCursor into r_cmpnt;
         EXIT WHEN updCursor%NOTFOUND;
         logMsg('Updating... '||r_cmpnt.name);
         UPDATE cmpnt
             SET
               cmpnt_type_id = r_cmpnt.cmpnt_type_id,
               name          = r_cmpnt.name
             WHERE
               cmpnt_id = r_cmpnt.cmpnt_id;
         tally := tally + 1;
     END LOOP;
     CLOSE updCursor;
     logMsg('cmpnt rows updated... '||tally);


    -- CMPNT_TYPE_PROP
    sqlStr :=  '
            select b.*
            from cmpnt_type_prop a, t_cmpnt_type_prop b
            where
                a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
                (
                    a.name <> b.name or
                    a.cmpnt_type_id <> b.cmpnt_type_id or
                    a.type <> b.type or
                    nvl(a.units,-1) <> nvl(b.units, -1) or
                    a.multipass <> b.multipass or
                    nvl(a.live_edit,-1) <> nvl(b.live_edit, -1) or
                    nvl(a.description,-1) <> nvl(b.description, -1) or
                    nvl(a.category_id,-1) <> nvl(b.category_id, -1)
                )';

    Open updCursor for sqlStr;

    tally := 0;
     LOOP
         FETCH updCursor into r_cmpnt_type_prop;
         EXIT WHEN updCursor%NOTFOUND;
         logMsg('Updating... '||r_cmpnt_type_prop.name);
         UPDATE cmpnt_type_prop
             SET
               cmpnt_type_id = r_cmpnt_type_prop.cmpnt_type_id,
               name          = r_cmpnt_type_prop.name,
               type          = r_cmpnt_type_prop.type,
               units         = r_cmpnt_type_prop.units,
               description   = r_cmpnt_type_prop.description,
               live_edit     = r_cmpnt_type_prop.live_edit,
               category_id   = r_cmpnt_type_prop.category_id,
               multipass     = r_cmpnt_type_prop.multipass
             WHERE
               cmpnt_type_prop_id = r_cmpnt_type_prop.cmpnt_type_prop_id;
         tally := tally + 1;
     END LOOP;
     CLOSE updCursor;
     logMsg('cmpnt_type_prop rows updated... '||tally);



    -- CMPNT_TYPE_PROP_DOM
    sqlStr :=  '
        select b.*
        from cmpnt_type_prop_dom a, t_cmpnt_type_prop_dom b
        where
            a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
            a.cmpnt_type_id = b.cmpnt_type_id and
            (
                nvl(a.domain,-1) <> nvl(b.domain, -1)
            )';

    Open updCursor for sqlStr;

    tally := 0;
     LOOP
         FETCH updCursor into r_cmpnt_type_prop_dom;
         EXIT WHEN updCursor%NOTFOUND;
          UPDATE cmpnt_type_prop_dom
              SET
                domain = r_cmpnt_type_prop_dom.domain
              WHERE
                cmpnt_type_prop_id = r_cmpnt_type_prop_dom.cmpnt_type_prop_id and
                cmpnt_type_id = r_cmpnt_type_prop_dom.cmpnt_type_id;
         tally := tally + 1;
     END LOOP;
     CLOSE updCursor;
     logMsg('cmpnt_type_prop_dom rows updated... '||tally);


    -- CMPNT_TYPE_PROP_DIM
    sqlStr :=  '
        select b.*
        from cmpnt_type_prop_dim a, t_cmpnt_type_prop_dim b
        where
            a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
            a.cmpnt_type_id = b.cmpnt_type_id and
            (
                a.dim1_max <> b.dim1_max or
                a.dim2_max <> b.dim2_max
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
         FETCH updCursor into r_cmpnt_type_prop_dim;
         EXIT WHEN updCursor%NOTFOUND;
          UPDATE cmpnt_type_prop_dim
              SET
                dim1_max = r_cmpnt_type_prop_dim.dim1_max,
                dim2_max = r_cmpnt_type_prop_dim.dim2_max
              WHERE
                cmpnt_type_prop_id = r_cmpnt_type_prop_dim.cmpnt_type_prop_id and
                cmpnt_type_id = r_cmpnt_type_prop_dim.cmpnt_type_id;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_type_prop_dim rows updated... '||tally);


    -- CMPNT_TYPE_PROP_REQ
    sqlStr :=  '
        select b.*
        from cmpnt_type_prop_req a, t_cmpnt_type_prop_req b
        where
            a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
            a.cmpnt_type_id = b.cmpnt_type_id and
            (
                a.required <> b.required
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
         FETCH updCursor into r_cmpnt_type_prop_req;
         EXIT WHEN updCursor%NOTFOUND;
         UPDATE cmpnt_type_prop_req
              SET
                required = r_cmpnt_type_prop_req.required
              WHERE
                cmpnt_type_prop_id = r_cmpnt_type_prop_req.cmpnt_type_prop_id and
                cmpnt_type_id = r_cmpnt_type_prop_req.cmpnt_type_id;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_type_prop_req rows updated... '||tally);

    -- CMPNT_TYPE_PROP_MIX
    sqlStr :=  '
        select b.*
        from cmpnt_type_prop_mix a, t_cmpnt_type_prop_mix b
        where
            a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
            a.cmpnt_type_id = b.cmpnt_type_id and
            a.indx = b.indx and
            (
                nvl(a.type,-1) <> nvl(b.type,-1) or
                nvl(a.label,-1) <> nvl(b.label,-1) or
                nvl(a.domain,-1) <> nvl(b.domain,-1) 
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
         FETCH updCursor into r_cmpnt_type_prop_mix;
         EXIT WHEN updCursor%NOTFOUND;
         UPDATE cmpnt_type_prop_mix
              SET
                type = r_cmpnt_type_prop_mix.type,
                label = r_cmpnt_type_prop_mix.label,
                domain = r_cmpnt_type_prop_mix.domain
              WHERE
                cmpnt_type_prop_id = r_cmpnt_type_prop_mix.cmpnt_type_prop_id and
                cmpnt_type_id = r_cmpnt_type_prop_mix.cmpnt_type_id and
                indx  = r_cmpnt_type_prop_mix.indx;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_type_prop_mix rows updated... '||tally);

    -- CMPNT_TYPE_PROP_DEF
    sqlStr :=  '
        select b.*
        from cmpnt_type_prop_def a, t_cmpnt_type_prop_def b
        where
            a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
            a.cmpnt_type_id = b.cmpnt_type_id and
            (
                nvl(a.value_default, -1) <> nvl(b.value_default, -1)
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_cmpnt_type_prop_def;
        EXIT WHEN updCursor%NOTFOUND;
        UPDATE cmpnt_type_prop_def
           SET
             value_default = r_cmpnt_type_prop_def.value_default
           WHERE
             cmpnt_type_prop_id = r_cmpnt_type_prop_def.cmpnt_type_prop_id and
             cmpnt_type_id = r_cmpnt_type_prop_def.cmpnt_type_id;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_type_prop_def rows updated... '||tally);


    -- CMPNT_TYPE_PROP_CATS
    sqlStr :=  '
        select b.*
        from cmpnt_type_prop_cats a, t_cmpnt_type_prop_cats b
        where
            a.category_id = b.category_id and
            (
               nvl( a.set_id, -1) <> nvl(b.set_id, -1) or
                a.category <> b.category or
                a.ordering <> b.ordering
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_cmpnt_type_prop_cats;
        EXIT WHEN updCursor%NOTFOUND;
           UPDATE cmpnt_type_prop_cats
               SET
                 set_id = r_cmpnt_type_prop_cats.set_id,
                 category = r_cmpnt_type_prop_cats.category,
                 ordering = r_cmpnt_type_prop_cats.ordering
               WHERE
                 category_id = r_cmpnt_type_prop_cats.category_id;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_type_prop_cats rows updated... '||tally);


    -- CATEGORY_SETS
    sqlStr :=  '
            select b.*
            from category_sets a, t_category_sets b
            where
                a.set_id = b.set_id and
                (
                    a.name <> b.name or
                    a.ordering <> b.ordering
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_category_sets;
        EXIT WHEN updCursor%NOTFOUND;
           UPDATE category_sets
               SET
                 name = r_category_sets.name,
                 ordering = r_category_sets.ordering
               WHERE
                 set_id = r_category_sets.set_id;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('category_sets rows updated... '||tally);



    -- ZONES
    sqlStr :=  '
        select b.*
        from zones a, t_zones b
        where
            a.zone_id = b.zone_id and
            (
                a.name <> b.name or
                nvl(a.description, -1) <> nvl(b.description, -1) or
                nvl(a.is_multi, -1) <> nvl(b.is_multi, -1) or
                nvl(a.contiguous, -1) <> nvl(b.contiguous, -1)
        )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_zones;
        EXIT WHEN updCursor%NOTFOUND;
         UPDATE zones
             SET
               name = r_zones.name,
               description = r_zones.description,
               is_multi = r_zones.is_multi,
               contiguous = r_zones.contiguous
             WHERE
               zone_id = r_zones.zone_id;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('zones rows updated... '||tally);

    -- ZONE_LINKS
    sqlStr :=  '
       select b.*
        from zone_links a, t_zone_links b
        where
            a.zone_links_id = b.zone_links_id and
            (
                a.zone_id <> b.zone_id or
                a.parent_zone_id <> b.parent_zone_id
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_zone_links;
        EXIT WHEN updCursor%NOTFOUND;
         UPDATE zone_links
             SET
               zone_id = r_zone_links.zone_id,
               parent_zone_id = r_zone_links.parent_zone_id
             WHERE
               zone_links_id = r_zone_links.zone_links_id;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('zone_links rows updated... '||tally);

    -- SEGMENTS
    sqlStr :=  '
        select b.*
        from segments a, t_segments b
        where
            a.segment_id = b.segment_id and
            (
                a.zone_id <> b.zone_id or
                nvl(a.mask, -1) <> nvl(b.mask, -1) or
                nvl(a.start_cmpnt, -1) <> nvl(b.start_cmpnt, -1) or
                nvl(a.start_pass, -1) <> nvl(b.start_pass, -1) or
                nvl(a.end_cmpnt, -1) <> nvl(b.end_cmpnt, -1) or
                nvl(a.end_pass, -1) <> nvl(b.end_pass, -1)
        )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_segments;
        EXIT WHEN updCursor%NOTFOUND;
         UPDATE segments
             SET
               zone_id = r_segments.zone_id,
               mask = r_segments.mask,
               start_cmpnt = r_segments.start_cmpnt,
               start_pass = r_segments.start_pass,
               end_cmpnt = r_segments.end_cmpnt,
               end_pass = r_segments.end_pass
             WHERE
               segment_id = r_segments.segment_id;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('segments rows updated... '||tally);


    -- CMPNT_PROP
    sqlStr :=  '
            select b.*
            from cmpnt_prop a, t_cmpnt_prop b
            where
                a.cmpnt_id = b.cmpnt_id and
                a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
                (
                    nvl(a.set_by, -1) <> nvl(b.set_by, -1) or
                    nvl(a.modify_date, sysdate) <> nvl(b.modify_date, sysdate) or
                    nvl(a.comments, -1) <> nvl(b.comments, -1)
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_cmpnt_prop;
        EXIT WHEN updCursor%NOTFOUND;
         UPDATE cmpnt_prop
             SET
               set_by = r_cmpnt_prop.set_by,
               modify_date = r_cmpnt_prop.modify_date,
               comments = r_cmpnt_prop.comments
             WHERE
               cmpnt_id = r_cmpnt_prop.cmpnt_id and
               cmpnt_type_prop_id = r_cmpnt_prop.cmpnt_type_prop_id;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_prop rows updated... '||tally);


    -- CMPNT_PROP_FK_CMPNT
    sqlStr :=  '
            select b.*
            from cmpnt_prop_fk_cmpnt a, t_cmpnt_prop_fk_cmpnt b
            where
                a.cmpnt_id = b.cmpnt_id and
                a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
                a.dim1 = b.dim1 and
                a.dim2 = b.dim2 and
                (
                    a.value <> b.value
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_cmpnt_prop_fk_cmpnt;
        EXIT WHEN updCursor%NOTFOUND;
         UPDATE cmpnt_prop_fk_cmpnt
             SET
               value = r_cmpnt_prop_fk_cmpnt.value,
               value_id = r_cmpnt_prop_fk_cmpnt.value_id
             WHERE
               cmpnt_id = r_cmpnt_prop_fk_cmpnt.cmpnt_id and
               cmpnt_type_prop_id = r_cmpnt_prop_fk_cmpnt.cmpnt_type_prop_id and
               dim1 = r_cmpnt_prop_fk_cmpnt.dim1 and
               dim2 = r_cmpnt_prop_fk_cmpnt.dim2;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_prop_fk_cmpnt rows updated... '||tally);



    -- CMPNT_PROP_BOOL
    sqlStr :=  '
            select b.*
            from cmpnt_prop_bool a, t_cmpnt_prop_bool b
            where
                a.cmpnt_id = b.cmpnt_id and
                a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
                a.dim1 = b.dim1 and
                a.dim2 = b.dim2 and
                (
                    a.value <> b.value
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_cmpnt_prop_bool;
        EXIT WHEN updCursor%NOTFOUND;
         UPDATE cmpnt_prop_bool
             SET
               value = r_cmpnt_prop_bool.value,
               value_id = r_cmpnt_prop_bool.value_id
             WHERE
               cmpnt_id = r_cmpnt_prop_bool.cmpnt_id and
               cmpnt_type_prop_id = r_cmpnt_prop_bool.cmpnt_type_prop_id and
               dim1 = r_cmpnt_prop_bool.dim1 and
               dim2 = r_cmpnt_prop_bool.dim2;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_prop_bool rows updated... '||tally);


    -- CMPNT_PROP_INTEGER
    sqlStr :=  '
            select b.*
            from cmpnt_prop_integer a, t_cmpnt_prop_integer b
            where
                a.cmpnt_id = b.cmpnt_id and
                a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
                a.dim1 = b.dim1 and
                a.dim2 = b.dim2 and
                (
                    a.value <> b.value
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_cmpnt_prop_integer;
        EXIT WHEN updCursor%NOTFOUND;
         UPDATE cmpnt_prop_integer
             SET
               value = r_cmpnt_prop_integer.value,
               value_id = r_cmpnt_prop_integer.value_id
             WHERE
               cmpnt_id = r_cmpnt_prop_integer.cmpnt_id and
               cmpnt_type_prop_id = r_cmpnt_prop_integer.cmpnt_type_prop_id and
               dim1 = r_cmpnt_prop_integer.dim1 and
               dim2 = r_cmpnt_prop_integer.dim2;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_prop_integer rows updated... '||tally);



    -- CMPNT_PROP_FLOAT
    sqlStr :=  '
            select b.*
            from cmpnt_prop_float a, t_cmpnt_prop_float b
            where
                a.cmpnt_id = b.cmpnt_id and
                a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
                a.dim1 = b.dim1 and
                a.dim2 = b.dim2 and
                (
                    a.value <> b.value
            )';

    Open updCursor for sqlStr;
    tally := 0;
    LOOP
        FETCH updCursor into r_cmpnt_prop_float;
        EXIT WHEN updCursor%NOTFOUND;
         UPDATE cmpnt_prop_float
             SET
               value = r_cmpnt_prop_float.value,
               value_id = r_cmpnt_prop_float.value_id
             WHERE
               cmpnt_id = r_cmpnt_prop_float.cmpnt_id and
               cmpnt_type_prop_id = r_cmpnt_prop_float.cmpnt_type_prop_id and
               dim1 = r_cmpnt_prop_float.dim1 and
               dim2 = r_cmpnt_prop_float.dim2;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_prop_float rows updated... '||tally);

    -- CMPNT_PROP_STRING

    sqlStr :=  '
            select b.*
            from cmpnt_prop_string a, t_cmpnt_prop_string b
            where
                a.cmpnt_id = b.cmpnt_id and
                a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
                a.dim1 = b.dim1 and
                a.dim2 = b.dim2 and
                (
                    a.value <> b.value
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_cmpnt_prop_string;
        EXIT WHEN updCursor%NOTFOUND;
         UPDATE cmpnt_prop_string
             SET
               value = r_cmpnt_prop_string.value,
               value_id = r_cmpnt_prop_string.value_id
             WHERE
               cmpnt_id = r_cmpnt_prop_string.cmpnt_id and
               cmpnt_type_prop_id = r_cmpnt_prop_string.cmpnt_type_prop_id and
               dim1 = r_cmpnt_prop_string.dim1 and
               dim2 = r_cmpnt_prop_string.dim2;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_prop_string rows updated... '||tally);


    -- CMPNT_PROP_DATE
    sqlStr :=  '
            select b.*
            from cmpnt_prop_date a, t_cmpnt_prop_date b
            where
                a.cmpnt_id = b.cmpnt_id and
                a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
                a.dim1 = b.dim1 and
                a.dim2 = b.dim2 and
                (
                    a.value <> b.value
            )';

    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_cmpnt_prop_date;
        EXIT WHEN updCursor%NOTFOUND;
         UPDATE cmpnt_prop_date
             SET
               value = r_cmpnt_prop_date.value,
               value_id = r_cmpnt_prop_date.value_id
             WHERE
               cmpnt_id = r_cmpnt_prop_date.cmpnt_id and
               cmpnt_type_prop_id = r_cmpnt_prop_date.cmpnt_type_prop_id and
               dim1 = r_cmpnt_prop_date.dim1 and
               dim2 = r_cmpnt_prop_date.dim2;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_prop_date rows updated... '||tally);

    -- CMPNT_PROP_BLOB


     sqlStr :=  '
             select b.*
            from cmpnt_prop_blob a, t_cmpnt_prop_blob b
            where
                a.cmpnt_id = b.cmpnt_id and
                a.cmpnt_type_prop_id = b.cmpnt_type_prop_id and
                a.dim1 = b.dim1 and
                a.dim2 = b.dim2 and
                (
                    nvl(a.value_md5, -1) <> nvl(b.value_md5, -1) or
                    nvl(a.mime_type, -1) <> nvl(b.mime_type, -1)
                )';

    -- logMsg(sqlStr);
    Open updCursor for sqlStr;

    tally := 0;
    LOOP
        FETCH updCursor into r_cmpnt_prop_blob;
        EXIT WHEN updCursor%NOTFOUND;
         UPDATE cmpnt_prop_blob
                SET value = r_cmpnt_prop_blob.value,
                    value_id = r_cmpnt_prop_blob.value_id,
                    value_md5 = r_cmpnt_prop_blob.value_md5,
                    mime_type = r_cmpnt_prop_blob.mime_type
                WHERE
                   cmpnt_id = r_cmpnt_prop_blob.cmpnt_id and
                   cmpnt_type_prop_id = r_cmpnt_prop_blob.cmpnt_type_prop_id and
                   dim1 = r_cmpnt_prop_blob.dim1 and
                   dim2 = r_cmpnt_prop_blob.dim2;
         tally := tally + 1;
    END LOOP;
    CLOSE updCursor;
    logMsg('cmpnt_prop_blob rows updated... '||tally);

     return;
END;


/**
* ------------------------------
*/


/**
* Merges a single element into parent workspace.
* Only operates on INVENTORY tables, so may fail if the
* CATALOG tables are out of sync between parent and child workspaces.
*
* @param wrkspc The name of the workspace containing element to be merged
* @param elem The name of the element to merge
* @throws ELEM_NOT_FOUND if the element does not exist as name in cmpnt table.
*/
PROCEDURE mergeElementByName (wrkspc IN VARCHAR2, elem IN VARCHAR2)
IS


v_cmpnt_id cmpnt.cmpnt_id%TYPE;

CURSOR cmpnt_id_cur (p_name IN VARCHAR2) IS
        SELECT cmpnt_id FROM cmpnt WHERE name = p_name;

cmpnt_where_clause VARCHAR2(1000);
sqlStr VARCHAR2(1000);
whereClause VARCHAR2(1000);

BEGIN

    logMsg('Beginning merge of '||elem);

    DBMS_WM.SetDiffVersions('LIVE',wrkspc);

    OPEN cmpnt_id_cur (elem);
    FETCH cmpnt_id_cur INTO v_cmpnt_id;
    IF cmpnt_id_cur%FOUND THEN
        logMsg('The cmpnt_id of '||elem||' is '||v_cmpnt_id);
        mergeElementByID(wrkspc, v_cmpnt_id);
 --       cmpnt_where_clause := 'cmpnt_id = '||v_cmpnt_id;
 --
 --       FOR n in 1 .. inventory_tables.count
 --       LOOP
 --           logMsg('update value table '||inventory_tables(n));
 --           DBMS_WM.MergeTable( workspace => wrkspc,
 --                               table_id => inventory_tables(n),
 --                               where_clause => cmpnt_where_clause,
 --                               auto_commit => false);
 --       END LOOP;
    ELSE
        RAISE ELEM_NOT_FOUND;
    END IF;

    CLOSE cmpnt_id_cur;


    EXCEPTION
        WHEN ELEM_NOT_FOUND THEN
            logMsg('EXCEPTION: '||elem||' not found');
            RAISE_APPLICATION_ERROR(-20000, 'EXCEPTION: '||elem||' not found');
        WHEN OTHERS THEN
               ROLLBACK;
               logMsg('EXCEPTION: Oracle Error '||SQLCODE);
               RAISE;       -- Re-throws

END;  -- mergeElementByName


/**
* Merges a single element into parent workspace.
* Only operates on INVENTORY tables, so may fail if the
* CATALOG tables are out of sync between parent and child workspaces.
*
* @param wrkspc The name of the workspace containing element to be merged
* @param elem The name of the element to merge
* @throws ELEM_NOT_FOUND if the element does not exist as name in cmpnt table.
*/
PROCEDURE mergeElementByID (wrkspc IN VARCHAR2, cmpnt_id IN INTEGER)
IS


cmpnt_where_clause VARCHAR2(1000);
sqlStr VARCHAR2(1000);
whereClause VARCHAR2(1000);

BEGIN

    logMsg('Beginning merge of element id '||cmpnt_id);

    DBMS_WM.SetDiffVersions('LIVE',wrkspc);

    cmpnt_where_clause := 'cmpnt_id = '|| cmpnt_id;

    FOR n in 1 .. inventory_tables.count
    LOOP
        logMsg('update value table '||inventory_tables(n));
        DBMS_WM.MergeTable( workspace => wrkspc,
                            table_id => inventory_tables(n),
                            where_clause => cmpnt_where_clause,
                            auto_commit => false);
    END LOOP;


    EXCEPTION
        WHEN OTHERS THEN
               ROLLBACK;
               logMsg('EXCEPTION: Oracle Error '||SQLCODE);
               RAISE;       -- Re-throws

END;  -- mergeElementByName


/**
* ------------------------------
*/


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

PROCEDURE refresh (wrkspc IN VARCHAR2, tableSet IN VARCHAR2 DEFAULT 'ALL')
IS


sqlStr VARCHAR2(1000);

BEGIN

    logMsg('Beginning refresh of '||wrkspc);


     DBMS_WM.SetDiffVersions('LIVE',wrkspc);

     IF upper(tableSet) = 'CATALOG' OR upper(tableSet) = 'ALL' THEN
        FOR n in 1 .. catalog_tables.count
        LOOP
            logMsg('update catalog table '||catalog_tables(n));
            DBMS_WM.RefreshTable( workspace => wrkspc,
                                  table_id => catalog_tables(n),
                                  auto_commit => false);
         END LOOP;
     END IF;

     IF upper(tableSet) = 'INVENTORY' OR upper(tableSet) = 'ALL' THEN
        FOR n in 1 .. inventory_tables.count
        LOOP
            logMsg('update inventory table '||inventory_tables(n));
            DBMS_WM.RefreshTable( workspace => wrkspc,
                                  table_id => inventory_tables(n),
                                  auto_commit => false);
         END LOOP;
     END IF;


     IF upper(tableSet) = 'ZONES' OR upper(tableSet) = 'ALL' THEN
        FOR n in 1 .. zone_tables.count
        LOOP
            logMsg('update zone table '||zone_tables(n));
            DBMS_WM.RefreshTable( workspace => wrkspc,
                                  table_id => zone_tables(n),
                                  auto_commit => false);
         END LOOP;
     END IF;



    EXCEPTION
        WHEN OTHERS THEN
               ROLLBACK;
               logMsg('EXCEPTION: Oracle Error '||SQLCODE);
               RAISE;       -- Re-throws
END;  -- refresh

/**
* ------------------------------
*/


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
PROCEDURE merge (wrkspc IN VARCHAR2, tableSet IN VARCHAR2 DEFAULT 'ALL')
IS


sqlStr VARCHAR2(1000);

BEGIN

    logMsg('Beginning merge of '||wrkspc);


     DBMS_WM.SetDiffVersions('LIVE',wrkspc);

     IF upper(tableSet) = 'CATALOG' OR upper(tableSet) = 'ALL' THEN
        FOR n in 1 .. catalog_tables.count
        LOOP
            logMsg('update catalog table '||catalog_tables(n));
            DBMS_WM.MergeTable( workspace => wrkspc,
                                  table_id => catalog_tables(n),
                                  auto_commit => false);
         END LOOP;
     END IF;

     IF upper(tableSet) = 'INVENTORY' OR upper(tableSet) = 'ALL' THEN
        FOR n in 1 .. inventory_tables.count
        LOOP
            logMsg('update inventory table '||inventory_tables(n));
            DBMS_WM.MergeTable( workspace => wrkspc,
                                  table_id => inventory_tables(n),
                                  auto_commit => false);
         END LOOP;
     END IF;


     IF upper(tableSet) = 'ZONES' OR upper(tableSet) = 'ALL' THEN
        FOR n in 1 .. zone_tables.count
        LOOP
            logMsg('update zone table '||zone_tables(n));
            DBMS_WM.MergeTable( workspace => wrkspc,
                                  table_id => zone_tables(n),
                                  auto_commit => false);
         END LOOP;
     END IF;



    EXCEPTION
        WHEN OTHERS THEN
               ROLLBACK;
               logMsg('EXCEPTION: Oracle Error '||SQLCODE);
               RAISE;       -- Re-throws
END;  -- merge

/**
* ------------------------------
*/


/**
* Wrapper for outputting errors, warnings, etc.
* Uses an autonomous transaction to write to admin_log table
* which may be monitored for status of long-running procedures.
* (We do this because there's no way to make Oracle flush the
* output of DBMS_OUTPUT.PUT_LINE calls that it's buffering until a
* procedure completes.
*
* @param msg The text to send to the log
* @param schema2use The schema into whose admin_log table to write
*/
PROCEDURE logMsg(msg IN VARCHAR2, schema2use IN VARCHAR2 DEFAULT NULL)
IS
    PRAGMA AUTONOMOUS_TRANSACTION;

sqlStr VARCHAR2(1000);

BEGIN
    DBMS_OUTPUT.PUT_LINE(sysdate||': '||msg);
    IF schema2use IS NOT NULL THEN
        sqlStr := 'insert into '||schema2use||'.admin_log
                        (log_id, logdate, logmsg)
                   values
                        ('||schema2use||'.log_id.nextval, sysdate, :msg)';
        EXECUTE IMMEDIATE sqlStr using msg;
    ELSE
        INSERT INTO admin_log (log_id, logdate, logmsg) values (log_id.nextval, sysdate, msg);
    END IF;


    COMMIT;  -- We are autonmous, so this is a local commit;

    -- Most likely exception would be non-existance of admin_log table
    EXCEPTION
        WHEN OTHERS THEN
        NULL;   -- NO OP


END;  -- logMsg

/**
* ------------------------------
*/



END CED_ADMIN;
/

