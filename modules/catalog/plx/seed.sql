-- Catalog seed — units, categories, articles, suppliers, pricing tiers
DO $$
DECLARE
  v_u_m int; v_u_m2 int; v_u_m3 int; v_u_ml int; v_u_h int; v_u_u int; v_u_fft int; v_u_kg int;
  v_cat_bois int; v_cat_massif int; v_cat_panneaux int;
  v_cat_quinc int; v_cat_isol int; v_cat_prest int; v_cat_fin int;
  v_a1 int; v_a2 int; v_a3 int; v_a4 int; v_a5 int;
  v_a6 int; v_a7 int; v_a8 int;
BEGIN
  -- Units of measure
  INSERT INTO catalog.unit (tenant_id, name, symbol) VALUES ('dev', 'Unité', 'u') ON CONFLICT DO NOTHING RETURNING id INTO v_u_u;
  INSERT INTO catalog.unit (tenant_id, name, symbol) VALUES ('dev', 'Mètre', 'm') ON CONFLICT DO NOTHING RETURNING id INTO v_u_m;
  INSERT INTO catalog.unit (tenant_id, name, symbol) VALUES ('dev', 'Mètre carré', 'm²') ON CONFLICT DO NOTHING RETURNING id INTO v_u_m2;
  INSERT INTO catalog.unit (tenant_id, name, symbol) VALUES ('dev', 'Mètre cube', 'm³') ON CONFLICT DO NOTHING RETURNING id INTO v_u_m3;
  INSERT INTO catalog.unit (tenant_id, name, symbol) VALUES ('dev', 'Mètre linéaire', 'ml') ON CONFLICT DO NOTHING RETURNING id INTO v_u_ml;
  INSERT INTO catalog.unit (tenant_id, name, symbol) VALUES ('dev', 'Heure', 'h') ON CONFLICT DO NOTHING RETURNING id INTO v_u_h;
  INSERT INTO catalog.unit (tenant_id, name, symbol) VALUES ('dev', 'Forfait', 'fft') ON CONFLICT DO NOTHING RETURNING id INTO v_u_fft;
  INSERT INTO catalog.unit (tenant_id, name, symbol) VALUES ('dev', 'Kilogramme', 'kg') ON CONFLICT DO NOTHING RETURNING id INTO v_u_kg;

  IF v_u_u IS NULL THEN SELECT id INTO v_u_u FROM catalog.unit WHERE symbol = 'u' AND tenant_id = 'dev'; END IF;
  IF v_u_m IS NULL THEN SELECT id INTO v_u_m FROM catalog.unit WHERE symbol = 'm' AND tenant_id = 'dev'; END IF;
  IF v_u_m2 IS NULL THEN SELECT id INTO v_u_m2 FROM catalog.unit WHERE symbol = 'm²' AND tenant_id = 'dev'; END IF;
  IF v_u_m3 IS NULL THEN SELECT id INTO v_u_m3 FROM catalog.unit WHERE symbol = 'm³' AND tenant_id = 'dev'; END IF;
  IF v_u_h IS NULL THEN SELECT id INTO v_u_h FROM catalog.unit WHERE symbol = 'h' AND tenant_id = 'dev'; END IF;

  -- Categories (hierarchical)
  INSERT INTO catalog.category (tenant_id, name, sort_order) VALUES ('dev', 'Bois', 1)
  ON CONFLICT DO NOTHING RETURNING id INTO v_cat_bois;
  IF v_cat_bois IS NULL THEN SELECT id INTO v_cat_bois FROM catalog.category WHERE name = 'Bois' AND tenant_id = 'dev'; END IF;

  INSERT INTO catalog.category (tenant_id, name, parent_id, sort_order) VALUES ('dev', 'Bois massif', v_cat_bois, 1)
  ON CONFLICT DO NOTHING RETURNING id INTO v_cat_massif;

  INSERT INTO catalog.category (tenant_id, name, parent_id, sort_order) VALUES ('dev', 'Panneaux', v_cat_bois, 2)
  ON CONFLICT DO NOTHING RETURNING id INTO v_cat_panneaux;

  INSERT INTO catalog.category (tenant_id, name, sort_order) VALUES ('dev', 'Quincaillerie', 2)
  ON CONFLICT DO NOTHING RETURNING id INTO v_cat_quinc;

  INSERT INTO catalog.category (tenant_id, name, sort_order) VALUES ('dev', 'Isolation', 3)
  ON CONFLICT DO NOTHING RETURNING id INTO v_cat_isol;

  INSERT INTO catalog.category (tenant_id, name, sort_order) VALUES ('dev', 'Prestations', 4)
  ON CONFLICT DO NOTHING RETURNING id INTO v_cat_prest;

  INSERT INTO catalog.category (tenant_id, name, sort_order) VALUES ('dev', 'Finition', 5)
  ON CONFLICT DO NOTHING RETURNING id INTO v_cat_fin;

  -- Articles with unit_id references
  INSERT INTO catalog.article (tenant_id, reference, name, description, category_id, unit_id, sale_price, purchase_price, vat_rate)
  VALUES ('dev', 'BOIS-CHE-001', 'Poutre chêne 200x80', 'Poutre chêne massif 200x80mm', v_cat_massif, v_u_m, 85.00, 52.00, 20)
  ON CONFLICT (reference) DO NOTHING RETURNING id INTO v_a1;

  INSERT INTO catalog.article (tenant_id, reference, name, description, category_id, unit_id, sale_price, purchase_price, vat_rate)
  VALUES ('dev', 'BOIS-DOU-001', 'Poutre Douglas 200x80', 'Poutre Douglas 200x80mm L=4m', v_cat_massif, v_u_m, 45.00, 28.00, 20)
  ON CONFLICT (reference) DO NOTHING RETURNING id INTO v_a2;

  INSERT INTO catalog.article (tenant_id, reference, name, category_id, unit_id, sale_price, purchase_price, vat_rate)
  VALUES ('dev', 'PAN-OSB-001', 'OSB3 2500x1250 18mm', v_cat_panneaux, v_u_m2, 12.50, 7.80, 20)
  ON CONFLICT (reference) DO NOTHING RETURNING id INTO v_a3;

  INSERT INTO catalog.article (tenant_id, reference, name, category_id, unit_id, sale_price, purchase_price, vat_rate)
  VALUES ('dev', 'QUINC-VIS-001', 'Vis à bois 6x80 (boîte 200)', v_cat_quinc, v_u_u, 18.90, 9.50, 20)
  ON CONFLICT (reference) DO NOTHING RETURNING id INTO v_a4;

  INSERT INTO catalog.article (tenant_id, reference, name, category_id, unit_id, sale_price, purchase_price, vat_rate)
  VALUES ('dev', 'ISOL-LDV-001', 'Laine de verre 200mm R=6', v_cat_isol, v_u_m2, 14.00, 8.20, 5.5)
  ON CONFLICT (reference) DO NOTHING RETURNING id INTO v_a5;

  INSERT INTO catalog.article (tenant_id, reference, name, category_id, unit_id, sale_price, vat_rate)
  VALUES ('dev', 'PREST-CHARP-001', 'Main d''oeuvre charpente', v_cat_prest, v_u_h, 55.00, 20)
  ON CONFLICT (reference) DO NOTHING RETURNING id INTO v_a6;

  INSERT INTO catalog.article (tenant_id, reference, name, category_id, unit_id, sale_price, vat_rate)
  VALUES ('dev', 'PREST-ISOL-001', 'Main d''oeuvre isolation', v_cat_prest, v_u_h, 45.00, 10)
  ON CONFLICT (reference) DO NOTHING RETURNING id INTO v_a7;

  INSERT INTO catalog.article (tenant_id, reference, name, category_id, unit_id, sale_price, purchase_price, vat_rate, active)
  VALUES ('dev', 'BOIS-EPI-OLD', 'Épicéa ancien (inactif)', v_cat_massif, v_u_m3, 180.00, 110.00, 20, false)
  ON CONFLICT (reference) DO NOTHING RETURNING id INTO v_a8;

  IF v_a1 IS NULL THEN RETURN; END IF;

  -- Suppliers
  INSERT INTO catalog.supplier_article (tenant_id, article_id, supplier_name, supplier_ref, cost_price, lead_time_days, moq, is_preferred) VALUES
    ('dev', v_a1, 'Scierie Dupont', 'SD-CHE-200', 48.00, 10, 20, true),
    ('dev', v_a1, 'Bois Import EU', 'BI-CHE-080', 52.00, 21, 50, false),
    ('dev', v_a2, 'Scierie Dupont', 'SD-DOU-200', 25.00, 7, 10, true),
    ('dev', v_a3, 'Panneaux Express', 'PE-OSB3-18', 7.20, 3, 100, true),
    ('dev', v_a4, 'Quincaillerie Pro', 'QP-VIS680', 8.50, 2, 50, true),
    ('dev', v_a5, 'Isover Direct', 'IS-LDV200', 7.50, 5, 200, true);

  -- Pricing tiers
  INSERT INTO catalog.pricing_tier (tenant_id, article_id, min_qty, unit_price) VALUES
    ('dev', v_a1, 1, 85.00), ('dev', v_a1, 20, 78.00), ('dev', v_a1, 50, 72.00),
    ('dev', v_a3, 1, 12.50), ('dev', v_a3, 50, 11.00), ('dev', v_a3, 200, 9.50),
    ('dev', v_a4, 1, 18.90), ('dev', v_a4, 10, 16.50),
    ('dev', v_a5, 1, 14.00), ('dev', v_a5, 100, 12.00);
END $$;
