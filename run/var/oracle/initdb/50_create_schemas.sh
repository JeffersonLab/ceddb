curl -ksLJO https://raw.githubusercontent.com/JeffersonLab/ceddb/master/sql/createSchema.sql
curl -ksLJO https://raw.githubusercontent.com/JeffersonLab/ceddb/master/sql/CED_ADMIN.pks
curl -ksLJO https://raw.githubusercontent.com/JeffersonLab/ceddb/master/sql/CED_ADMIN.pkb
-- for schema in CED3_OWNER CED3_DEVL CED3_OPS CED3_HIST
for schema in CED3_OWNER
do
  # The ${!variable} syntax is for variable variable
  echo execute createSchema for ${schema}/${!schema}
  echo "grant own_ced to ${schema};" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
  echo exit | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1 @createSchema.sql
  echo exit | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1 @CED_ADMIN.pks
  echo exit | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1 @CED_ADMIN.pkb
  # Unfortunately can't grant package excute to a role, so must do each user individually
  echo "grant execute on ${schema}.CED_ADMIN to read_ced;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
  echo "grant execute on ${schema}.CED_ADMIN to ced3_ops;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
  echo "create public synonym CED_ADMIN for ${schema}.CED_ADMIN;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
  echo "grant select on event_id to read_ced;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
  echo "grant select on web_auth to read_ced;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
  echo "grant select, insert on hist_cmpnt to ced3_ops;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
  echo "grant select, insert on hist_cmpnt_prop to ced3_ops;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
  echo "grant select, insert on hist_cmpnt_prop_val to ced3_ops;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
#  echo "grant select on web_auth to read_ced;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
#  echo "grant select on admin_lock to read_ced;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
done

for schema in CED3_DEVL CED3_OPS CED3_HIST
do
    echo execute createSchema for ${schema}/${!schema}
    echo "grant read_ced to ${schema};" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
    echo exit | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1 @createSchema.sql
    echo "create synonym CED_ADMIN for ced3_owner.CED_ADMIN;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
    echo "exec CED_ADMIN.grantPermissions();" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
    echo "drop synonym staff;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
    echo "create synonym staff for ced3_owner.staff;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
    echo "drop synonym workgroup;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
    echo "create synonym workgroup for ced3_owner.workgroup;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
    echo "drop synonym workgroup_membership;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
    echo "create synonym workgroup_membership for ced3_owner.workgroup_membership;" | sqlplus -s ${schema}/${!schema}@//localhost/XEPDB1
done

rm createSchema.sql
rm CED_ADMIN.pks
rm CED_ADMIN.pkb
