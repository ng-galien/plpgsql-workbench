-- Demo data for shop schema
-- Idempotent: uses ON CONFLICT DO NOTHING

INSERT INTO shop.customers (id, name, email) VALUES
  (1, 'Marie Dupont', 'marie@demo.com'),
  (2, 'Jean Martin', 'jean@demo.com'),
  (3, 'Sophie Bernard', 'sophie@demo.com')
ON CONFLICT DO NOTHING;

INSERT INTO shop.products (id, name, price, stock) VALUES
  (1, 'Laptop Pro', 1299.00, 15),
  (2, 'Wireless Mouse', 29.99, 200),
  (3, 'USB-C Hub', 49.99, 50),
  (4, 'Monitor 27"', 399.00, 8),
  (5, 'Keyboard', 79.99, 120),
  (6, 'Webcam HD', 59.99, 30)
ON CONFLICT DO NOTHING;

INSERT INTO shop.discounts (code, kind, value, min_order, buy_x, get_y_free, active) VALUES
  ('WELCOME10', 'percentage', 10, 50, NULL, NULL, true),
  ('FLAT25', 'fixed', 25, 100, NULL, NULL, true),
  ('B3G1', 'buy_x_get_y', 0, 0, 3, 1, true),
  ('EXPIRED50', 'percentage', 50, 0, NULL, NULL, false)
ON CONFLICT DO NOTHING;

-- Reset sequences to avoid conflicts with future inserts
SELECT setval('shop.customers_id_seq', (SELECT COALESCE(MAX(id), 0) FROM shop.customers));
SELECT setval('shop.products_id_seq', (SELECT COALESCE(MAX(id), 0) FROM shop.products));
