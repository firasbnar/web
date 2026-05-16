DROP TABLE IF EXISTS otp_audit_logs;
DROP TABLE IF EXISTS phone_otp_verifications;

ALTER TABLE users DROP COLUMN IF EXISTS phone_verified;
ALTER TABLE users DROP COLUMN IF EXISTS firebase_uid;
