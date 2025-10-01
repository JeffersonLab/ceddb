ALTER SESSION SET CONTAINER=XEPDB1;

-- Make sure our application passwords won't expire on us by changing the default password policy
-- This must be done before the users are created and assigned the policy.
ALTER PROFILE DEFAULT LIMIT FAILED_LOGIN_ATTEMPTS UNLIMITED PASSWORD_LIFE_TIME UNLIMITED;
