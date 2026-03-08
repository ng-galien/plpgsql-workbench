CREATE SCHEMA IF NOT EXISTS shop;
CREATE SCHEMA IF NOT EXISTS shop_ut;

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
  buy_x integer,       -- for buy_x_get_y: buy X items
  get_y_free integer,  -- for buy_x_get_y: get Y free
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
