ALTER TABLE boutiques
  ADD COLUMN store_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  ADD COLUMN frozen_at TIMESTAMP NULL,
  ADD COLUMN freeze_reason TEXT NULL;

CREATE TABLE admin_audit_logs (
  id UUID PRIMARY KEY,
  admin_id UUID NOT NULL,
  admin_email VARCHAR(255) NOT NULL,
  action VARCHAR(50) NOT NULL,
  target_type VARCHAR(20) NOT NULL,
  target_id UUID,
  details TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_admin_audit_logs_created ON admin_audit_logs(created_at DESC);
CREATE INDEX idx_admin_audit_logs_admin ON admin_audit_logs(admin_id);
CREATE INDEX idx_admin_audit_logs_target ON admin_audit_logs(target_type, target_id);
