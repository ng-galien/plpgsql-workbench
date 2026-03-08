-- Shop schema
CREATE SCHEMA IF NOT EXISTS shop;

CREATE TABLE IF NOT EXISTS shop.customers (
  id serial PRIMARY KEY,
  name text NOT NULL,
  email text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS shop.products (
  id serial PRIMARY KEY,
  name text NOT NULL,
  price numeric(10,2) NOT NULL CHECK (price > 0),
  stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0)
);

CREATE TABLE IF NOT EXISTS shop.discounts (
  code text PRIMARY KEY,
  kind text NOT NULL CHECK (kind IN ('percentage', 'fixed', 'buy_x_get_y')),
  value numeric(10,2) NOT NULL,
  min_order numeric(10,2) DEFAULT 0,
  buy_x integer,
  get_y_free integer,
  active boolean DEFAULT true,
  expires_at timestamptz
);

CREATE TABLE IF NOT EXISTS shop.orders (
  id serial PRIMARY KEY,
  customer_id integer NOT NULL REFERENCES shop.customers(id),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'shipped', 'cancelled')),
  subtotal numeric(10,2) NOT NULL DEFAULT 0,
  discount_amount numeric(10,2) NOT NULL DEFAULT 0,
  total numeric(10,2) NOT NULL DEFAULT 0,
  discount_code text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS shop.order_items (
  id serial PRIMARY KEY,
  order_id integer NOT NULL REFERENCES shop.orders(id) ON DELETE CASCADE,
  product_id integer NOT NULL REFERENCES shop.products(id),
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price numeric(10,2) NOT NULL,
  subtotal numeric(10,2) NOT NULL
);

-- PostgREST roles
CREATE ROLE web_anon NOLOGIN;
GRANT USAGE ON SCHEMA shop TO web_anon;
GRANT SELECT ON ALL TABLES IN SCHEMA shop TO web_anon;
GRANT INSERT, UPDATE ON shop.orders, shop.order_items TO web_anon;
GRANT UPDATE ON shop.products TO web_anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA shop TO web_anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA shop TO web_anon;

CREATE ROLE authenticator LOGIN PASSWORD 'authenticator';
GRANT web_anon TO authenticator;
