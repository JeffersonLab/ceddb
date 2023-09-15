ALTER SESSION SET CONTAINER=XEPDB1;

-- On the production server, the ced_notify function calls an external C routine in
-- a shared library ced_notify.so.  Here it's just a no-op function that always returns 0.
-- Without this function present, the CED_ADMIN package won't compile later on.
CREATE OR REPLACE function CED3_OWNER.ced_notify(deployment IN char, ced_event IN char) return binary_integer
as
begin
  return 0;
end;
/