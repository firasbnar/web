-- Token-based invitation acceptance is removed.
-- User accounts are created immediately on invite; email verification replaces invitation acceptance.
-- The team_invitations table now serves purely as audit/business metadata.

ALTER TABLE team_invitations ALTER COLUMN token DROP NOT NULL;
ALTER TABLE team_invitations DROP CONSTRAINT IF EXISTS team_invitations_token_key;
DROP INDEX IF EXISTS idx_team_invitations_token;

ALTER TABLE team_invitations ALTER COLUMN token_expires_at DROP NOT NULL;
