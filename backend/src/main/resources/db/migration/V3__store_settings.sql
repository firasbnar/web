-- Add email, phone, address columns to boutiques
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS email VARCHAR(200);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS phone VARCHAR(50);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS timezone VARCHAR(50) DEFAULT 'Africa/Tunis';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS banner_url TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS favicon_url TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS og_image_url TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS font_family VARCHAR(100) DEFAULT 'Inter';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS dark_mode BOOLEAN DEFAULT FALSE;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS stripe_publishable_key VARCHAR(200);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS stripe_secret_key VARCHAR(200);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS stripe_webhook_secret VARCHAR(200);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS paypal_client_id VARCHAR(200);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS paypal_secret VARCHAR(200);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS paypal_webhook_id VARCHAR(200);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS free_shipping_threshold DECIMAL(10,2);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS estimated_delivery_days INT DEFAULT 3;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS enable_local_pickup BOOLEAN DEFAULT FALSE;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS enable_email_notifications BOOLEAN DEFAULT TRUE;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS enable_sms_notifications BOOLEAN DEFAULT FALSE;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS enable_push_notifications BOOLEAN DEFAULT TRUE;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS enable_marketing_emails BOOLEAN DEFAULT FALSE;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS enable_order_alerts BOOLEAN DEFAULT TRUE;

-- Delivery zones table
CREATE TABLE IF NOT EXISTS delivery_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  countries TEXT DEFAULT '',
  fee DECIMAL(10,2) DEFAULT 0.00,
  min_order_amount DECIMAL(10,2),
  estimated_days INT DEFAULT 3,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_delivery_zones_boutique ON delivery_zones(boutique_id);

-- Accepted countries are stored as ISO 3166-1 alpha-2 codes per boutique.
CREATE TABLE IF NOT EXISTS boutique_countries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  country_code VARCHAR(2) NOT NULL
);
ALTER TABLE boutique_countries ADD COLUMN IF NOT EXISTS country_code VARCHAR(2);
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'boutique_countries' AND column_name = 'country_name'
  ) THEN
    EXECUTE 'ALTER TABLE boutique_countries ALTER COLUMN country_name DROP NOT NULL';
    EXECUTE 'ALTER TABLE boutique_countries ALTER COLUMN country_name TYPE VARCHAR(100)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'boutique_countries' AND column_name = 'country_name'
  ) THEN
    EXECUTE 'UPDATE boutique_countries SET country_code = UPPER(SUBSTRING(country_name FROM 1 FOR 2)) WHERE country_code IS NULL AND country_name IS NOT NULL';
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_boutique_countries_boutique ON boutique_countries(boutique_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_boutique_countries_boutique_code
  ON boutique_countries(boutique_id, country_code);

-- Notification config table
CREATE TABLE IF NOT EXISTS notification_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE UNIQUE,
  email_enabled BOOLEAN DEFAULT TRUE,
  sms_enabled BOOLEAN DEFAULT FALSE,
  push_enabled BOOLEAN DEFAULT TRUE,
  order_confirmation BOOLEAN DEFAULT TRUE,
  order_shipped BOOLEAN DEFAULT TRUE,
  order_delivered BOOLEAN DEFAULT TRUE,
  new_customer_welcome BOOLEAN DEFAULT TRUE,
  low_stock_alert BOOLEAN DEFAULT TRUE,
  marketing_emails BOOLEAN DEFAULT FALSE,
  email_from_address VARCHAR(200),
  sms_provider VARCHAR(50) DEFAULT 'none',
  sms_api_key VARCHAR(200),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Sessions table for JWT session management
CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL,
  device_info VARCHAR(255),
  ip_address VARCHAR(45),
  is_active BOOLEAN DEFAULT TRUE,
  last_activity TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id);

-- Billing/invoice history table
CREATE TABLE IF NOT EXISTS invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
  amount DECIMAL(10,2) NOT NULL,
  currency VARCHAR(10) DEFAULT 'TND',
  status VARCHAR(20) DEFAULT 'PENDING',
  payment_method VARCHAR(50),
  payment_ref VARCHAR(100),
  invoice_data JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_invoices_user ON invoices(user_id);
