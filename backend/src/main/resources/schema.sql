ALTER TABLE users ADD COLUMN IF NOT EXISTS active_boutique_id UUID REFERENCES boutiques(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_boutiques_user ON boutiques(user_id);

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
  sender_role VARCHAR(10) NOT NULL,
  content TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_messages_boutique ON messages(boutique_id);
CREATE INDEX IF NOT EXISTS idx_messages_customer ON messages(customer_id);

CREATE TABLE IF NOT EXISTS team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(20) DEFAULT 'STAFF',
  invited_email VARCHAR(150),
  status VARCHAR(20) DEFAULT 'PENDING',
  invited_at TIMESTAMP DEFAULT NOW(),
  joined_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_team_members_boutique ON team_members(boutique_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_team_members_boutique_email_lower
  ON team_members (boutique_id, lower(invited_email))
  WHERE invited_email IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_team_members_boutique_user
  ON team_members (boutique_id, user_id)
  WHERE user_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  customer_name VARCHAR(100),
  rating INT CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  owner_reply TEXT,
  is_approved BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS boutique_templates (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  preview_url TEXT,
  thumbnail_url TEXT,
  is_premium BOOLEAN DEFAULT FALSE
);

INSERT INTO boutique_templates (name, is_premium) VALUES 
  ('Classic', false),
  ('Modern', false),
  ('Minimal', false),
  ('Premium Shop', true),
  ('Fashion Store', true)
ON CONFLICT DO NOTHING;

ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS template_id INT REFERENCES boutique_templates(id);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS client_messaging_enabled BOOLEAN DEFAULT TRUE;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS team_enabled BOOLEAN DEFAULT FALSE;

-- Product new fields
ALTER TABLE products ADD COLUMN IF NOT EXISTS purchase_price DECIMAL(10,2);
ALTER TABLE products ADD COLUMN IF NOT EXISTS colors VARCHAR(500);
ALTER TABLE products ADD COLUMN IF NOT EXISTS sizes VARCHAR(500);
ALTER TABLE products ADD COLUMN IF NOT EXISTS description_html TEXT;
ALTER TABLE products ALTER COLUMN images SET DEFAULT '[]';

-- User new fields
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_reason TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP;

-- Team member name
ALTER TABLE team_members ADD COLUMN IF NOT EXISTS name VARCHAR(100);

-- Store views new columns for traffic analytics
ALTER TABLE store_views ADD COLUMN IF NOT EXISTS page VARCHAR(200);
ALTER TABLE store_views ADD COLUMN IF NOT EXISTS referrer TEXT;
ALTER TABLE store_views ADD COLUMN IF NOT EXISTS browser VARCHAR(50);
ALTER TABLE store_views ADD COLUMN IF NOT EXISTS country VARCHAR(100);
ALTER TABLE store_views ADD COLUMN IF NOT EXISTS city VARCHAR(100);
ALTER TABLE store_views ADD COLUMN IF NOT EXISTS user_agent TEXT;
ALTER TABLE store_views ADD COLUMN IF NOT EXISTS visitor_id VARCHAR(64);
ALTER TABLE store_views ALTER COLUMN source TYPE VARCHAR(50) USING source::varchar(50);

-- Super admin audit log
CREATE TABLE IF NOT EXISTS admin_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES users(id),
  action_type VARCHAR(50),
  target_user_id UUID,
  target_boutique_id UUID,
  details JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_views_viewed_at ON store_views(viewed_at);

-- ========== STORE CONFIG & E-COMMERCE STOREFRONT ==========

-- Add store_config TEXT + new columns to boutiques
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS store_config TEXT DEFAULT '{}';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS generated_html TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS header_color VARCHAR(7) DEFAULT '#ededed';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS footer_color VARCHAR(7) DEFAULT '#dbdbdb';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS body_color VARCHAR(7) DEFAULT '#ffffff';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS card_product_color VARCHAR(7) DEFAULT '#fafafa';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS button_color VARCHAR(7) DEFAULT '#b551c2';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS top_bar_color VARCHAR(7) DEFAULT '#3b0086';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS text_color VARCHAR(7) DEFAULT '#751515';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS announcement_text TEXT DEFAULT 'توصيل خلال 48 ساعة في أنحاء تونس';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS delivery_fees DECIMAL(10,2) DEFAULT 7.00;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS tva DECIMAL(5,2) DEFAULT 0.00;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS simple_checkout BOOLEAN DEFAULT FALSE;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS cash_on_delivery BOOLEAN DEFAULT TRUE;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS stripe_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS stripe_status VARCHAR(50) DEFAULT 'DISABLED';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS konnect_merchant_id VARCHAR(100);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS konnect_api_key VARCHAR(200);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS konnect_status VARCHAR(20) DEFAULT 'inactive';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS d17_merchant_number VARCHAR(50);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS d17_qr_code_url TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS d17_status VARCHAR(20) DEFAULT 'inactive';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS custom_js TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS twitter_url TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS linkedin_url TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS facebook_pixel_id VARCHAR(50);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS google_analytics_id VARCHAR(50);

-- Customer aggregation fields
ALTER TABLE customers ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS country VARCHAR(100);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS total_orders INT DEFAULT 0;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS total_spent DECIMAL(12,2) DEFAULT 0.00;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS last_order_date TIMESTAMP;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP;
CREATE INDEX IF NOT EXISTS idx_customers_boutique_email ON customers(boutique_id, email);

-- Store sliders for hero carousel
CREATE TABLE IF NOT EXISTS store_sliders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_store_sliders_boutique ON store_sliders(boutique_id);

-- Store videos gallery
CREATE TABLE IF NOT EXISTS store_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  video_url TEXT NOT NULL,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Store language translations
CREATE TABLE IF NOT EXISTS store_language (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE UNIQUE,
  add_to_cart VARCHAR(100) DEFAULT 'Ajouter au panier',
  checkout_title VARCHAR(100) DEFAULT 'Commande',
  total_price_label VARCHAR(100) DEFAULT 'Prix Total :',
  shipping_cost_label VARCHAR(100) DEFAULT 'Frais de livraison',
  grand_total_label VARCHAR(100) DEFAULT 'Total Général',
  full_name_placeholder VARCHAR(200) DEFAULT 'Entrez votre nom complet',
  email_placeholder VARCHAR(200) DEFAULT 'Entrez votre e-mail',
  billing_address_placeholder VARCHAR(200) DEFAULT 'Entrez votre adresse de livraison',
  city_placeholder VARCHAR(200) DEFAULT 'Sélectionnez votre gouvernorat',
  phone_placeholder VARCHAR(200) DEFAULT 'Entrez votre numéro de téléphone',
  payment_method_label VARCHAR(100) DEFAULT 'Méthode de paiement :',
  place_order_button VARCHAR(100) DEFAULT 'Passer la commande',
  no_products VARCHAR(200) DEFAULT 'Aucun produit disponible pour le moment.',
  footer_text VARCHAR(200) DEFAULT 'Tous droits réservés.',
  order_confirmation_title VARCHAR(100) DEFAULT 'Confirmation de commande',
  search_products VARCHAR(100) DEFAULT 'Rechercher des produits...',
  see_all VARCHAR(50) DEFAULT 'Voir tout',
  cash_on_delivery VARCHAR(100) DEFAULT 'Paiement à la livraison',
  follow_us VARCHAR(50) DEFAULT 'Suivez-nous',
  support VARCHAR(50) DEFAULT 'Support',
  menu_label VARCHAR(50) DEFAULT 'Menu',
  cart_title VARCHAR(100) DEFAULT 'Panier',
  select_country VARCHAR(100) DEFAULT 'Sélectionnez votre pays'
);

-- Reviews schema migration for new entity structure
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES products(id) ON DELETE CASCADE;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'PENDING';

-- Accepted countries per boutique
CREATE TABLE IF NOT EXISTS boutique_countries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  country_code VARCHAR(2) NOT NULL,
  UNIQUE(boutique_id, country_code)
);
ALTER TABLE boutique_countries ADD COLUMN IF NOT EXISTS country_code VARCHAR(2);
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

-- Conversations for customer-to-store messaging
CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID NOT NULL REFERENCES boutiques(id) ON DELETE CASCADE,
  customer_name VARCHAR(150) NOT NULL,
  customer_email VARCHAR(150) NOT NULL,
  customer_phone VARCHAR(20),
  last_message_at TIMESTAMP NOT NULL DEFAULT NOW(),
  last_message_preview TEXT,
  unread_count INTEGER DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_conversations_boutique ON conversations(boutique_id);

-- Extend messages table with conversation support
ALTER TABLE messages ADD COLUMN IF NOT EXISTS conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS customer_name VARCHAR(150);
ALTER TABLE messages ADD COLUMN IF NOT EXISTS customer_email VARCHAR(150);
ALTER TABLE messages ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(20);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
