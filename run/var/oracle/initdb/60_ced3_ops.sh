cd /opt/oracle/oradata/impdb/

# Drop empty schema and recreated it
echo "drop user ced3_ops cascade;" | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "create user ced3_ops identified by \"dflTPassWD\" account unlock;" \
    | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "grant execute on ced3_owner.ced_admin to ced3_ops;" \
    | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "grant execute on dbms_crypto to ced3_ops;" \
    | sqlplus -s sys/dflTPassWD@XEPDB1 as sysdba

impdp system/dflTPassWD@xepdb1 exclude=user directory=import_data_dir dumpfile=ced.dmp schemas=ced3_ops \
    exclude="user,statistics,table:\"in(\'usage_log\',\'admin_log\')\""
echo "drop table admin_log;" \
    | sqlplus -s ced3_ops/dflTPassWD@//localhost/XEPDB1
echo "create synonym admin_log for ced3_owner.admin_log;" \
    | sqlplus -s ced3_ops/dflTPassWD@//localhost/XEPDB1

