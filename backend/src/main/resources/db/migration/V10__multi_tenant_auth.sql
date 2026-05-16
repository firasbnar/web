CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS tenant_id UUID;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS tenant_id UUID;

INSERT INTO tenants (id, name, active, created_at)
SELECT gen_random_uuid(), COALESCE(NULLIF(full_name, ''), email, id::TEXT) || ' Tenant', TRUE, NOW()
FROM users u
WHERE u.tenant_id IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM tenants t WHERE t.name = COALESCE(NULLIF(u.full_name, ''), u.email, u.id::TEXT) || ' Tenant'
  );

UPDATE users u
SET tenant_id = t.id
FROM tenants t
WHERE u.tenant_id IS NULL
  AND t.name = COALESCE(NULLIF(u.full_name, ''), u.email, u.id::TEXT) || ' Tenant';

UPDATE boutiques b
SET tenant_id = u.tenant_id
FROM users u
WHERE b.user_id = u.id
  AND b.tenant_id IS NULL;

ALTER TABLE users ALTER COLUMN tenant_id SET NOT NULL;
ALTER TABLE boutiques ALTER COLUMN tenant_id SET NOT NULL;

ALTER TABLE users
    ADD CONSTRAINT fk_users_tenant
    FOREIGN KEY (tenant_id) REFERENCES tenants(id);

ALTER TABLE boutiques
    ADD CONSTRAINT fk_boutiques_tenant
    FOREIGN KEY (tenant_id) REFERENCES tenants(id);

CREATE INDEX IF NOT EXISTS idx_users_tenant_id ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_boutiques_tenant_id ON boutiques(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_tenant_user ON users(tenant_id, id);
CREATE INDEX IF NOT EXISTS idx_boutiques_tenant_boutique ON boutiques(tenant_id, id);
