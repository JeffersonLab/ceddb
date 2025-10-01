echo "boohoo!!"

echo "drop synonym ced3_ops.event_id;" \
 | sqlplus -s system/dflTPassWD@//localhost/XEPDB1

# Import data into the unversioned ops schema
impdp system/dflTPassWD@xepdb1 exclude=user directory=import_data_dir dumpfile=ced.dmp schemas=ced3_ops \
     exclude="user,statistics,table:\"in(\'usage_log\',\'admin_log\')\",synonym:\"in(\'event_id\')\""

# Remove the admin_log table and replace it with synonym to ced3_owner admin_log table
echo "drop table admin_log;" \
 | sqlplus -s ced3_ops/dflTPassWD@//localhost/XEPDB1
echo "create synonym admin_log for ced3_owner.admin_log;" \
 | sqlplus -s ced3_ops/dflTPassWD@//localhost/XEPDB1
# Drop the logoff trigger -- we're not supporting history in this container image right now
echo "drop trigger ced3_ops.ced_logoff;" \
 | sqlplus -s ced3_ops/dflTPassWD@//localhost/XEPDB1

# Import data into the dev schema and enable versioning afterwards
impdp system/dflTPassWD@xepdb1 directory=import_data_dir dumpfile=ced.dmp remap_schema=ced3_ops:ced3_devl \
 exclude="user,trigger,statistics,table:\"in(\'usage_log\',\'admin_log\')\""
# Remove the admin_log table and replace it with synonym to ced3_owner admin_log table
echo "alter user ced3_devl identified by \"dflTPassWD\" account unlock;" \
 | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "drop table admin_log;" \
 | sqlplus -s ced3_devl/dflTPassWD@//localhost/XEPDB1
echo "create synonym admin_log for ced3_owner.admin_log;" \
 | sqlplus -s ced3_devl/dflTPassWD@//localhost/XEPDB1
# Enable versioning
echo "Enabling CED versioning.  This will take a while..."
echo exit | sqlplus -s ced3_devl/dflTPassWD@//localhost/XEPDB1 @enableCEDVersioning.sql
echo "CED version enabling complete."
