ALTER TABLE invoices ADD COLUMN IF NOT EXISTS boutique_id UUID REFERENCES boutiques(id) ON DELETE SET NULL;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS order_id UUID REFERENCES orders(id) ON DELETE CASCADE;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(40);

CREATE UNIQUE INDEX IF NOT EXISTS idx_invoices_order_id ON invoices(order_id) WHERE order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_invoices_boutique_id ON invoices(boutique_id);
CREATE INDEX IF NOT EXISTS idx_invoices_invoice_number ON invoices(invoice_number);
