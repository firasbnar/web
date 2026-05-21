-- MakeWebsite.io PostgreSQL Schema
-- Run this file to initialize the database

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(150) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  phone VARCHAR(20),
  role VARCHAR(20) DEFAULT 'OWNER',
  language VARCHAR(10) DEFAULT 'fr',
  telegram_chat_id VARCHAR(50),
  avatar_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  expires_at TIMESTAMP NOT NULL
);

CREATE TABLE plans (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  price_dt DECIMAL(10,2) NOT NULL,
  duration_days INT NOT NULL,
  max_products INT DEFAULT 250,
  commission_percent DECIMAL(5,2) DEFAULT 0.00,
  features JSONB
);

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  plan_id INT REFERENCES plans(id),
  status VARCHAR(20) DEFAULT 'ACTIVE',
  started_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP NOT NULL,
  payment_method VARCHAR(30),
  payment_ref VARCHAR(100)
);

CREATE TABLE boutiques (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  logo_url TEXT,
  description TEXT,
  custom_domain VARCHAR(200),
  primary_color VARCHAR(7) DEFAULT '#2710BF',
  secondary_color VARCHAR(7) DEFAULT '#6C4FFF',
  currency VARCHAR(10) DEFAULT 'TND',
  language VARCHAR(10) DEFAULT 'fr',
  is_active BOOLEAN DEFAULT TRUE,
  seo_title VARCHAR(200),
  seo_description TEXT,
  seo_keywords TEXT,
  facebook_url TEXT,
  instagram_url TEXT,
  tiktok_url TEXT,
  whatsapp_number VARCHAR(20),
  custom_css TEXT,
  enable_cod BOOLEAN DEFAULT TRUE,
  enable_d17 BOOLEAN DEFAULT FALSE,
  enable_adeex BOOLEAN DEFAULT FALSE,
  enable_jax BOOLEAN DEFAULT FALSE,
  enable_intigo BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(100) NOT NULL,
  image_url TEXT,
  sort_order INT DEFAULT 0
);

CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  compare_price DECIMAL(10,2),
  stock INT DEFAULT 0,
  sku VARCHAR(100),
  weight DECIMAL(8,3),
  images JSONB DEFAULT '[]',
  is_active BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  seo_title VARCHAR(200),
  seo_description TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(150),
  phone VARCHAR(20),
  address TEXT,
  city VARCHAR(100),
  governorate VARCHAR(100),
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  order_number VARCHAR(30) UNIQUE NOT NULL,
  status VARCHAR(30) DEFAULT 'PENDING',
  subtotal DECIMAL(10,2) NOT NULL,
  shipping_fee DECIMAL(10,2) DEFAULT 0,
  discount DECIMAL(10,2) DEFAULT 0,
  total DECIMAL(10,2) NOT NULL,
  payment_method VARCHAR(30),
  payment_status VARCHAR(20) DEFAULT 'UNPAID',
  payment_ref VARCHAR(100),
  shipping_address TEXT,
  delivery_company VARCHAR(50),
  tracking_number VARCHAR(100),
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  product_name VARCHAR(200) NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  quantity INT NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL
);

CREATE TABLE pos_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id),
  opened_at TIMESTAMP DEFAULT NOW(),
  closed_at TIMESTAMP,
  opening_cash DECIMAL(10,2) DEFAULT 0,
  closing_cash DECIMAL(10,2),
  total_sales DECIMAL(10,2) DEFAULT 0,
  notes TEXT
);

CREATE TABLE pos_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES pos_sessions(id) ON DELETE CASCADE,
  order_id UUID REFERENCES orders(id),
  total DECIMAL(10,2) NOT NULL,
  payment_method VARCHAR(30),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE boutique_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  config_key VARCHAR(100) NOT NULL,
  config_value TEXT,
  UNIQUE(boutique_id, config_key)
);

CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  customer_name VARCHAR(100) NOT NULL,
  rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  owner_reply TEXT,
  status VARCHAR(20) DEFAULT 'PENDING',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE product_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  price DECIMAL(10,2),
  stock INT,
  sku VARCHAR(100),
  sort_order INT DEFAULT 0,
  image_url TEXT
);

CREATE TABLE coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  code VARCHAR(50) UNIQUE NOT NULL,
  discount_type VARCHAR(20),
  discount_value DECIMAL(10,2) NOT NULL,
  min_order_amount DECIMAL(10,2),
  max_uses INT,
  used_count INT DEFAULT 0,
  expires_at TIMESTAMP,
  is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  event_type VARCHAR(50),
  product_id UUID,
  order_id UUID,
  source VARCHAR(50),
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE ai_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(10) NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE wishlist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, product_id)
);

CREATE TABLE carts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  boutique_id UUID REFERENCES boutiques(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, boutique_id)
);

CREATE TABLE cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cart_id UUID REFERENCES carts(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  quantity INT NOT NULL DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  body TEXT,
  type VARCHAR(30),
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Seed plans
INSERT INTO plans (name, price_dt, duration_days, max_products, commission_percent, features) VALUES
('Gratuit',  0,   3,  10,  5.00, '["Jusqu a 10 produits","Commission 5%","Support email"]'),
('3 Mois',   99,  90, 250, 0.00, '["Jusqu a 250 produits","Sans commission","Domaine personnalisé","Support prioritaire","Intégration livraison"]'),
('Premium',  35,  30, 999, 0.00, '["Produits illimités","Sans commission","Domaine personnalisé","Support 24/7","POS inclus","Assistant IA","Analytics avancés","CSS personnalisé"]');

CREATE TABLE store_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boutique_id UUID,
  ip_hash VARCHAR(64),
  source VARCHAR(50),
  page VARCHAR(200),
  referrer TEXT,
  browser VARCHAR(50),
  country VARCHAR(100),
  city VARCHAR(100),
  user_agent TEXT,
  viewed_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_products_boutique ON products(boutique_id);
CREATE INDEX idx_product_variants_product ON product_variants(product_id);
CREATE INDEX idx_reviews_product ON reviews(product_id);
CREATE INDEX idx_orders_boutique ON orders(boutique_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created ON orders(created_at);
CREATE INDEX idx_customers_boutique ON customers(boutique_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_ai_conversations_user ON ai_conversations(user_id);
