-- Replaced by temp-password-after-verification flow.
-- Password setup tokens were never shipped; clean up if present.
ALTER TABLE users DROP COLUMN IF EXISTS password_setup_token;
ALTER TABLE users DROP COLUMN IF EXISTS password_setup_token_expiry;
