-- Sequential invoice numbering per boutique
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS invoice_sequence BIGINT DEFAULT 0;

-- Invoice fields on orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(30);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS invoice_created_at TIMESTAMP;

-- Index for looking up orders by invoice number
CREATE INDEX IF NOT EXISTS idx_orders_invoice_number ON orders(invoice_number);

-- Boutique Konnect/D17 payment config (if missing)
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS konnect_api_secret VARCHAR(200);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS d17_api_key VARCHAR(200);
