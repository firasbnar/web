ALTER TABLE boutiques
    ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS published_at TIMESTAMP;

-- Set existing stores as published so they remain visible
UPDATE boutiques SET is_published = true WHERE is_published IS NULL OR is_published = false;
UPDATE boutiques SET published_at = created_at WHERE published_at IS NULL AND is_published = true;
