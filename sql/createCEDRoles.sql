PROMPT '*******************************************'
PROMPT '* NOTE: This script must be run as sysdba *'
PROMPT '*******************************************'
PROMPT


-- Creation
Create ROLE OWN_CED;
Create ROLE READ_CED;


-- Insurance to make sure OWN_CED always has privileges granted to READ_CED
GRANT READ_CED to OWN_CED;


-- General System Privileges

GRANT CREATE PUBLIC SYNONYM to OWN_CED;

-- With Workspaces enabled only full exports are possible!
-- Hence we run CED in its own instance and no other users.
-- GRANT EXP_FULL_DATABASE TO OWN_CED;

-- in order to create md5 hashes of blob values
GRANT EXECUTE ON DBMS_CRYPTO TO READ_CED;
GRANT CONNECT TO READ_CED;




-- Workspace Manager Permissions for OWN_CED

begin
dbms_wm.grantsystempriv('ACCESS_ANY_WORKSPACE', 'OWN_CED', 'NO');
end;
/

begin
dbms_wm.grantsystempriv('CREATE_ANY_WORKSPACE', 'OWN_CED', 'NO');
end;
/

begin
dbms_wm.grantsystempriv('MERGE_ANY_WORKSPACE', 'OWN_CED', 'NO');
end;
/

begin
dbms_wm.grantsystempriv('REMOVE_ANY_WORKSPACE', 'OWN_CED', 'NO');
end;
/

begin
dbms_wm.grantsystempriv('ROLLBACK_ANY_WORKSPACE', 'OWN_CED', 'NO');
end;

/


-- Workspace Manager Permissions for READ_CED

begin
dbms_wm.grantsystempriv('ACCESS_ANY_WORKSPACE', 'READ_CED', 'NO');
end;
/

/*
GRANT SELECT ON WMSYS.WM$MODIFIED_TABLES TO READ_CED;
GRANT SELECT ON WMSYS.WM$NEXTVER_TABLE TO READ_CED;
GRANT SELECT ON WMSYS.WM$VERSION_HIERARCHY_TABLE TO READ_CED;
GRANT SELECT ON WMSYS.WM$VERSION_TABLE TO READ_CED;
GRANT SELECT ON WMSYS.WM$WORKSPACES_TABLE TO READ_CED;

grant wm_admin_role to ced3_devl;
*/