-- expense — seed data (reference categories)

SELECT set_config('app.tenant_id', '_ref', false);

INSERT INTO expense.category (name, accounting_code) VALUES
  ('Vehicle travel', '625100'),
  ('Transport (train, plane)', '625200'),
  ('Accommodation', '625600'),
  ('Meals', '625700'),
  ('Supplies', '606400'),
  ('Tools', '606300'),
  ('Phone/Internet', '626000'),
  ('Miscellaneous', '625800')
ON CONFLICT DO NOTHING;
