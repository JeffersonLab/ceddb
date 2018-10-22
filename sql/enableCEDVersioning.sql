/**
*
* @see https://accwiki.acc.jlab.org/do/view/AHLA/CEDVersioningImplementation
* @see http://devweb/oradocs/11g/appdev.111/b28396/long_intro.htm#i1016953
*
*/


-- All tables with FK relationships must be versioned.

-- Be patient!  The function below can take several (5+) minutes to complete.  
-- EXECUTE DBMS_WM.EnableVersioning ('cmpnt_type, cmpnt_type_owners, cmpnt, cmpnt_owners, cmpnt_type_prop, cmpnt_prop, cmpnt_type_prop_def, cmpnt_type_prop_dom, cmpnt_type_prop_dim, cmpnt_type_prop_req, cmpnt_type_prop_owners, cmpnt_type_prop_cats, category_sets, cmpnt_prop_fk_cmpnt, cmpnt_prop_bool, cmpnt_prop_integer, cmpnt_prop_float, cmpnt_prop_string, cmpnt_prop_date, cmpnt_prop_blob, zones, zone_links, segments', 'VIEW_WO_OVERWRITE');

-- Version 4 below adds cmpnt_type_prop_mix table
EXECUTE DBMS_WM.EnableVersioning ('cmpnt_type, cmpnt_type_owners, cmpnt, cmpnt_owners, cmpnt_type_prop, cmpnt_prop, cmpnt_type_prop_def, cmpnt_type_prop_dom, cmpnt_type_prop_dim, cmpnt_type_prop_req, cmpnt_type_prop_mix, cmpnt_type_prop_owners, cmpnt_type_prop_cats, category_sets, cmpnt_prop_fk_cmpnt, cmpnt_prop_bool, cmpnt_prop_integer, cmpnt_prop_float, cmpnt_prop_string, cmpnt_prop_date, cmpnt_prop_blob, zones, zone_links, segments', 'VIEW_WO_OVERWRITE');


-- The corresponding Disable command should it be required
-- EXECUTE DBMS_WM.DisableVersioning ('cmpnt_type, cmpnt_type_owners, cmpnt, cmpnt_owners, cmpnt_type_prop, cmpnt_prop, cmpnt_type_prop_def, cmpnt_type_prop_dom, cmpnt_type_prop_dim, cmpnt_type_prop_req, cmpnt_type_prop_mix, cmpnt_type_prop_owners, cmpnt_type_prop_cats, category_sets, cmpnt_prop_fk_cmpnt, cmpnt_prop_bool, cmpnt_prop_integer, cmpnt_prop_float, cmpnt_prop_string, cmpnt_prop_date, cmpnt_prop_blob, zones, zone_links, segments');



 
/*
exec dbms_wm.gotoworkspace('LIVE');
exec dbms_wm.createworkspace('_dev','Workspace to be used as parent of most other workspaces');
exec dbms_wm.gotoworkspace('_dev');
exec dbms_wm.createworkspace('LCW','Refactor the LCW Valve properties');
exec dbms_wm.createworkspace('IOCDev','Controls Group Workspace');
exec dbms_wm.createworkspace('FSDDev','Workspace to refactor IOCard Channels');

select workspace, parent_workspace from all_workspaces;
*/