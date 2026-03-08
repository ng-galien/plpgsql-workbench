-- Demo seed data
INSERT INTO shop.customers (name, email) VALUES
  ('Marie Dupont', 'marie@demo.com'),
  ('Jean Martin', 'jean@demo.com'),
  ('Sophie Bernard', 'sophie@demo.com');

INSERT INTO shop.products (name, price, stock) VALUES
  ('Laptop Pro', 1299.00, 15),
  ('Wireless Mouse', 29.99, 200),
  ('USB-C Hub', 49.99, 50),
  ('Monitor 27"', 399.00, 8),
  ('Keyboard', 79.99, 120),
  ('Webcam HD', 59.99, 30);

INSERT INTO shop.discounts (code, kind, value, min_order, buy_x, get_y_free, active) VALUES
  ('WELCOME10', 'percentage', 10, 50, NULL, NULL, true),
  ('FLAT25', 'fixed', 25, 100, NULL, NULL, true),
  ('B3G1', 'buy_x_get_y', 0, 0, 3, 1, true),
  ('EXPIRED50', 'percentage', 50, 0, NULL, NULL, false);
