ALTER TABLE conversations ADD COLUMN IF NOT EXISTS guest_token VARCHAR(255) UNIQUE;
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS status VARCHAR(10) DEFAULT 'OPEN' NOT NULL;
ALTER TABLE conversations ALTER COLUMN customer_email DROP NOT NULL;
CREATE INDEX IF NOT EXISTS idx_conversations_guest_token ON conversations(guest_token);
