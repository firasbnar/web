-- Storefront tables and boutique columns migration

-- Add missing columns to boutiques table
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS store_config JSONB DEFAULT '{}';
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
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS konnect_merchant_id VARCHAR(100);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS konnect_api_key VARCHAR(200);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS konnect_status VARCHAR(20) DEFAULT 'inactive';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS d17_merchant_number VARCHAR(50);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS d17_qr_code_url TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS d17_status VARCHAR(20) DEFAULT 'inactive';
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS custom_js TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS facebook_pixel_id VARCHAR(50);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS google_analytics_id VARCHAR(50);
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS twitter_url TEXT;
ALTER TABLE boutiques ADD COLUMN IF NOT EXISTS linkedin_url TEXT;

-- Store sliders table
CREATE TABLE IF NOT EXISTS store_sliders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Store language table
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

-- Store videos table
CREATE TABLE IF NOT EXISTS store_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  video_url TEXT NOT NULL,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Accepted countries per boutique
CREATE TABLE IF NOT EXISTS boutique_countries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  country_name VARCHAR(100) NOT NULL,
  UNIQUE(boutique_id, country_name)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_store_sliders_boutique ON store_sliders(boutique_id);
CREATE INDEX IF NOT EXISTS idx_store_videos_boutique ON store_videos(boutique_id);
CREATE INDEX IF NOT EXISTS idx_boutique_countries_boutique ON boutique_countries(boutique_id);
