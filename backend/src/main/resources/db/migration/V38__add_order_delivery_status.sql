ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS delivery_status VARCHAR(30);

