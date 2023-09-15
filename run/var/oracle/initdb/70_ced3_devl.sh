cd /opt/oracle/oradata/impdb/

# Drop empty schema and recreated it
echo "drop user ced3_devl cascade;" | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "create user ced3_devl identified by \"dflTPassWD\" account unlock;" \
  | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "grant execute on ced3_owner.ced_admin to ced3_devl;" \
  | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "grant execute on dbms_crypto to ced3_devl;" \
  | sqlplus -s sys/dflTPassWD@XEPDB1 as sysdba

impdp system/dflTPassWD@xepdb1 directory=import_data_dir dumpfile=ced.dmp remap_schema=ced3_ops:ced3_devl \
  exclude="user,trigger,statistics,table:\"in(\'usage_log\',\'admin_log\')\""
echo "alter user ced3_devl identified by \"dflTPassWD\" account unlock;" \
  | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "drop table admin_log;" \
  | sqlplus -s ced3_devl/dflTPassWD@//localhost/XEPDB1
echo "create synonym admin_log for ced3_owner.admin_log;" \
  | sqlplus -s ced3_devl/dflTPassWD@//localhost/XEPDB1

echo "Enabling CED versioning.  This will take a while..."
echo exit | sqlplus -s ced3_devl/dflTPassWD@//localhost/XEPDB1 @enableCEDVersioning.sql
echo "CED version enabling complete."