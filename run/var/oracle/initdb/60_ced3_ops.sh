cd /opt/oracle/oradata/impdb/

# Drop empty schema and recreated it
echo "drop user ced3_ops cascade;" | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "create user ced3_ops identified by \"dflTPassWD\" account unlock;" \
    | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "grant execute on ced3_owner.ced_admin to ced3_ops;" \
    | sqlplus -s system/dflTPassWD@//localhost/XEPDB1

echo "grant select, insert on ced3_owner.hist_cmpnt to ced3_ops;" \
    | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "grant select, insert on ced3_owner.hist_cmpnt_prop to ced3_ops;" \
    | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "grant select, insert on ced3_owner.hist_cmpnt_prop_val to ced3_ops;" \
    | sqlplus -s system/dflTPassWD@//localhost/XEPDB1
echo "grant select on ced3_owner.event_id to ced3_ops;" \
    | sqlplus -s system/dflTPassWD@//localhost/XEPDB1

echo "grant execute on dbms_crypto to ced3_ops;" \
    | sqlplus -s sys/dflTPassWD@XEPDB1 as sysdba


