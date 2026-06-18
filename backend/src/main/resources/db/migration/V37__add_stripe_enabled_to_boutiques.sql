ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS stripe_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS stripe_status VARCHAR(50) DEFAULT 'DISABLED';

UPDATE boutiques
SET stripe_enabled = CASE
    WHEN stripe_enabled IS TRUE THEN TRUE
    WHEN LOWER(COALESCE(stripe_status, '')) IN ('active', 'enabled', 'true') THEN TRUE
    ELSE FALSE
END;

UPDATE boutiques
SET stripe_status = CASE
    WHEN stripe_enabled IS TRUE THEN 'ENABLED'
    ELSE 'DISABLED'
END;
