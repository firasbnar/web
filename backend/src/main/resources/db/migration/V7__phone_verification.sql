-- Add phone verified field to users
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN DEFAULT FALSE;

-- Phone OTP verification table
CREATE TABLE IF NOT EXISTS phone_otp_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    phone_number VARCHAR(20) NOT NULL,
    otp_code VARCHAR(255) NOT NULL,
    attempts INT DEFAULT 0,
    max_attempts INT DEFAULT 5,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_phone_otp_user ON phone_otp_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_phone_otp_expires ON phone_otp_verifications(expires_at);
