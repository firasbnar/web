ALTER TABLE activity_logs
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'SUCCESS',
    ADD COLUMN IF NOT EXISTS ip_address VARCHAR(45),
    ADD COLUMN IF NOT EXISTS device_info VARCHAR(255),
    ADD COLUMN IF NOT EXISTS session_id UUID,
    ADD COLUMN IF NOT EXISTS metadata TEXT;

ALTER TABLE activity_logs
    ALTER COLUMN action TYPE VARCHAR(50);

CREATE INDEX IF NOT EXISTS idx_activity_logs_user ON activity_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_status ON activity_logs(status, created_at DESC);
