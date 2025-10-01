cd /opt/oracle/oradata/impdb/

# Drop empty schema and recreated it
echo "drop user ced3_devl cascade;" | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "create user ced3_devl identified by \"dflTPassWD\" account unlock;" \
  | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "grant execute on ced3_owner.ced_admin to ced3_devl;" \
  | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "grant execute on dbms_crypto to ced3_devl;" \
  | sqlplus -s sys/dflTPassWD@XEPDB1 as sysdba
