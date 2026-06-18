ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS stripe_status VARCHAR(20) DEFAULT 'inactive';
