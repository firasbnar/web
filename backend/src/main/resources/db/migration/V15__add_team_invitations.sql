CREATE TABLE IF NOT EXISTS team_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boutique_id UUID NOT NULL REFERENCES boutiques(id) ON DELETE CASCADE,
    invited_email VARCHAR(150) NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    token_expires_at TIMESTAMP NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'STAFF',
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    accepted_at TIMESTAMP
);

ALTER TABLE team_members
    ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS invitation_token VARCHAR(255),
    ADD COLUMN IF NOT EXISTS name VARCHAR(100);

CREATE INDEX IF NOT EXISTS idx_team_invitations_boutique ON team_invitations(boutique_id, status);
CREATE INDEX IF NOT EXISTS idx_team_invitations_token ON team_invitations(token);
CREATE INDEX IF NOT EXISTS idx_team_invitations_email ON team_invitations(invited_email, status);
CREATE INDEX IF NOT EXISTS idx_team_members_last_activity ON team_members(boutique_id, last_activity_at DESC);
