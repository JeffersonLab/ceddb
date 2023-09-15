# We create the users via shell command where we have access
# to the password env variables.  Later in user_grants.sql script, we will
# fine tune their default tablespace and permissions.
createAppUser CED3_OWNER $CED3_OWNER
createAppUser CED3_DEVL $CED3_DEVL
createAppUser CED3_OPS $CED3_OPS
createAppUser CED3_HIST $CED3_HIST
