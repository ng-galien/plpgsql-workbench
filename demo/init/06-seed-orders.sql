-- Sample orders for pgView demo
SELECT shop.place_order(1, '[{"product_id":1,"quantity":1},{"product_id":3,"quantity":2}]'::jsonb, 'WELCOME10');
SELECT shop.place_order(2, '[{"product_id":4,"quantity":1},{"product_id":5,"quantity":1}]'::jsonb, 'FLAT25');
SELECT shop.place_order(3, '[{"product_id":1,"quantity":1},{"product_id":6,"quantity":2}]'::jsonb);
SELECT shop.place_order(1, '[{"product_id":2,"quantity":5},{"product_id":5,"quantity":1}]'::jsonb);
SELECT shop.place_order(2, '[{"product_id":3,"quantity":1}]'::jsonb);

-- Cancel one order for demo variety
SELECT shop.cancel_order(5);
