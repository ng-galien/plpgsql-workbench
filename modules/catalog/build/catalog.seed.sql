-- catalog — Seed data (référence, partagé entre tenants)
SELECT set_config('app.tenant_id', '_ref', false);

-- Unités de mesure
INSERT INTO catalog.unite (code, label) VALUES
  ('u', 'Unité'),
  ('m', 'Mètre'),
  ('m2', 'Mètre carré'),
  ('m3', 'Mètre cube'),
  ('kg', 'Kilogramme'),
  ('l', 'Litre'),
  ('h', 'Heure'),
  ('forfait', 'Forfait'),
  ('ml', 'Mètre linéaire')
ON CONFLICT DO NOTHING;

-- i18n keys
SELECT catalog.i18n_seed();
