-- Reduce OTP code column for HMAC-SHA256 (64 hex chars)
ALTER TABLE phone_otp_verifications ALTER COLUMN otp_code TYPE VARCHAR(64);

-- OTP audit log table
CREATE TABLE IF NOT EXISTS otp_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(20) NOT NULL,
    phone_number VARCHAR(20),
    ip_address VARCHAR(45),
    metadata VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otp_audit_user ON otp_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_otp_audit_created ON otp_audit_logs(created_at);

-- Index for cleanup queries
CREATE INDEX IF NOT EXISTS idx_phone_otp_cleanup ON phone_otp_verifications(expires_at, used);
