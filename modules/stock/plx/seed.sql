-- Dev seed for stock module
DO $$
DECLARE
  v_wh_workshop int;
  v_wh_vehicle  int;
  v_oak int; v_douglas int; v_screw int; v_bolt int; v_osb int;
  v_wool int; v_oil int; v_glue int; v_bracket int; v_nail int;
  v_supplier_wood int; v_supplier_hardware int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Skip if already seeded
  IF EXISTS (SELECT 1 FROM stock.warehouse WHERE tenant_id = 'dev') THEN RETURN; END IF;

  SELECT id INTO v_supplier_wood FROM crm.client WHERE name = 'Scierie du Jura' AND tenant_id = 'dev';
  IF NOT FOUND THEN
    INSERT INTO crm.client (name, type, city, tenant_id)
    VALUES ('Scierie du Jura', 'company', 'Arbois', 'dev')
    RETURNING id INTO v_supplier_wood;
  END IF;

  SELECT id INTO v_supplier_hardware FROM crm.client WHERE name = 'Quincaillerie Pro' AND tenant_id = 'dev';
  IF NOT FOUND THEN
    INSERT INTO crm.client (name, type, city, tenant_id)
    VALUES ('Quincaillerie Pro', 'company', 'Besançon', 'dev')
    RETURNING id INTO v_supplier_hardware;
  END IF;

  INSERT INTO stock.warehouse (name, type, address, tenant_id)
    VALUES ('Atelier principal', 'workshop', '12 rue des Chênes, Lons-le-Saunier', 'dev')
    RETURNING id INTO v_wh_workshop;
  INSERT INTO stock.warehouse (name, type, tenant_id)
    VALUES ('Véhicule utilitaire', 'vehicle', 'dev')
    RETURNING id INTO v_wh_vehicle;
  INSERT INTO stock.warehouse (name, type, address, tenant_id)
    VALUES ('Chantier Martin', 'job_site', '8 impasse des Tilleuls, Poligny', 'dev');

  INSERT INTO stock.article (reference, description, category, unit, purchase_price, wap, min_threshold, supplier_id, tenant_id)
    VALUES ('BOIS-CHENE-27', 'Chêne massif 27mm', 'wood', 'm3', 850.00, 850.00, 2, v_supplier_wood, 'dev') RETURNING id INTO v_oak;
  INSERT INTO stock.article (reference, description, category, unit, purchase_price, wap, min_threshold, supplier_id, tenant_id)
    VALUES ('BOIS-DOUG-45', 'Douglas 45mm', 'wood', 'm3', 420.00, 420.00, 3, v_supplier_wood, 'dev') RETURNING id INTO v_douglas;
  INSERT INTO stock.article (reference, description, category, unit, purchase_price, wap, min_threshold, supplier_id, tenant_id)
    VALUES ('QUINC-VIS-5x50', 'Vis inox 5x50 (boîte 200)', 'hardware', 'ea', 18.50, 18.50, 5, v_supplier_hardware, 'dev') RETURNING id INTO v_screw;
  INSERT INTO stock.article (reference, description, category, unit, purchase_price, wap, min_threshold, supplier_id, tenant_id)
    VALUES ('QUINC-TIRE-8x80', 'Tirefond 8x80 (boîte 50)', 'hardware', 'ea', 24.00, 24.00, 3, v_supplier_hardware, 'dev') RETURNING id INTO v_bolt;
  INSERT INTO stock.article (reference, description, category, unit, purchase_price, wap, min_threshold, supplier_id, tenant_id)
    VALUES ('PAN-OSB-18', 'OSB 18mm 2500x1250', 'panel', 'ea', 32.00, 32.00, 10, v_supplier_wood, 'dev') RETURNING id INTO v_osb;
  INSERT INTO stock.article (reference, description, category, unit, purchase_price, wap, min_threshold, supplier_id, tenant_id)
    VALUES ('ISOL-LAINE-60', 'Laine de bois 60mm', 'insulation', 'm2', 8.50, 8.50, 20, v_supplier_wood, 'dev') RETURNING id INTO v_wool;
  INSERT INTO stock.article (reference, description, category, unit, purchase_price, wap, supplier_id, tenant_id)
    VALUES ('FIN-HUILE-LIN', 'Huile de lin 5L', 'finish', 'ea', 35.00, 35.00, v_supplier_hardware, 'dev') RETURNING id INTO v_oil;
  INSERT INTO stock.article (reference, description, category, unit, purchase_price, wap, supplier_id, tenant_id)
    VALUES ('FIN-COLLE-PU', 'Colle PU D4 750g', 'finish', 'ea', 22.00, 22.00, v_supplier_hardware, 'dev') RETURNING id INTO v_glue;
  INSERT INTO stock.article (reference, description, category, unit, purchase_price, wap, min_threshold, supplier_id, tenant_id)
    VALUES ('QUINC-EQUER-90', 'Équerre 90° renforcée', 'hardware', 'ea', 3.50, 3.50, 20, v_supplier_hardware, 'dev') RETURNING id INTO v_bracket;
  INSERT INTO stock.article (reference, description, category, unit, purchase_price, wap, supplier_id, tenant_id)
    VALUES ('QUINC-POINT-70', 'Pointe tête plate 70mm (kg)', 'hardware', 'kg', 8.00, 8.00, v_supplier_hardware, 'dev') RETURNING id INTO v_nail;

  INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, reference, tenant_id) VALUES
    (v_oak,     v_wh_workshop, 'entry', 5,   850.00, 'BL-2026-001', 'dev'),
    (v_douglas, v_wh_workshop, 'entry', 8,   420.00, 'BL-2026-001', 'dev'),
    (v_screw,   v_wh_workshop, 'entry', 20,  18.50,  'BL-2026-002', 'dev'),
    (v_bolt,    v_wh_workshop, 'entry', 10,  24.00,  'BL-2026-002', 'dev'),
    (v_osb,     v_wh_workshop, 'entry', 30,  32.00,  'BL-2026-003', 'dev'),
    (v_wool,    v_wh_workshop, 'entry', 50,  8.50,   'BL-2026-003', 'dev'),
    (v_oil,     v_wh_workshop, 'entry', 6,   35.00,  'BL-2026-004', 'dev'),
    (v_glue,    v_wh_workshop, 'entry', 8,   22.00,  'BL-2026-004', 'dev'),
    (v_bracket, v_wh_workshop, 'entry', 50,  3.50,   'BL-2026-005', 'dev'),
    (v_nail,    v_wh_workshop, 'entry', 10,  8.00,   'BL-2026-005', 'dev'),
    (v_oak,     v_wh_workshop, 'exit',  -2,  850.00, 'CHANTIER-MARTIN', 'dev'),
    (v_osb,     v_wh_workshop, 'exit',  -8,  32.00,  'CHANTIER-MARTIN', 'dev'),
    (v_screw,   v_wh_workshop, 'exit',  -5,  18.50,  'CHANTIER-MARTIN', 'dev'),
    (v_wool,    v_wh_workshop, 'exit',  -35, 8.50,   'CHANTIER-DUPONT', 'dev');

  INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, destination_warehouse_id, reference, tenant_id) VALUES
    (v_bracket, v_wh_workshop, 'transfer', -15, 3.50, v_wh_vehicle, 'TRANSFERT-001', 'dev'),
    (v_bracket, v_wh_vehicle,  'transfer',  15, 3.50, v_wh_workshop, 'TRANSFERT-001', 'dev');

  INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, reference, tenant_id) VALUES
    (v_nail, v_wh_workshop, 'inventory', -2, 'INV-20260310', 'dev');

  INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, reference, tenant_id) VALUES
    (v_douglas, v_wh_workshop, 'entry', 4, 450.00, 'BL-2026-006', 'dev');

END $$;
