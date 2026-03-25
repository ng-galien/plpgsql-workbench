-- stock — Language rename: French → English
-- Tables, columns, status values, constraints

-- 1. RENAME TABLES
ALTER TABLE IF EXISTS stock.mouvement RENAME TO movement;
ALTER TABLE IF EXISTS stock.depot RENAME TO warehouse;

-- 2. RENAME COLUMNS — stock.article
ALTER TABLE stock.article RENAME COLUMN designation TO description;
ALTER TABLE stock.article RENAME COLUMN categorie TO category;
ALTER TABLE stock.article RENAME COLUMN unite TO unit;
ALTER TABLE stock.article RENAME COLUMN prix_achat TO purchase_price;
ALTER TABLE stock.article RENAME COLUMN pmp TO wap;
ALTER TABLE stock.article RENAME COLUMN seuil_mini TO min_threshold;
ALTER TABLE stock.article RENAME COLUMN fournisseur_id TO supplier_id;

-- 3. RENAME COLUMNS — stock.warehouse (ex-depot)
ALTER TABLE stock.warehouse RENAME COLUMN nom TO name;
ALTER TABLE stock.warehouse RENAME COLUMN adresse TO address;
ALTER TABLE stock.warehouse RENAME COLUMN actif TO active;

-- 4. RENAME COLUMNS — stock.movement (ex-mouvement)
ALTER TABLE stock.movement RENAME COLUMN quantite TO quantity;
ALTER TABLE stock.movement RENAME COLUMN prix_unitaire TO unit_price;
ALTER TABLE stock.movement RENAME COLUMN depot_id TO warehouse_id;
ALTER TABLE stock.movement RENAME COLUMN depot_destination_id TO destination_warehouse_id;

-- 5. DROP OLD CHECK CONSTRAINTS FIRST (before updating values)
ALTER TABLE stock.movement DROP CONSTRAINT IF EXISTS mouvement_type_check;
ALTER TABLE stock.movement DROP CONSTRAINT IF EXISTS movement_type_check;
ALTER TABLE stock.article DROP CONSTRAINT IF EXISTS article_categorie_check;
ALTER TABLE stock.article DROP CONSTRAINT IF EXISTS article_category_check;
ALTER TABLE stock.article DROP CONSTRAINT IF EXISTS article_unite_check;
ALTER TABLE stock.article DROP CONSTRAINT IF EXISTS article_unit_check;
ALTER TABLE stock.warehouse DROP CONSTRAINT IF EXISTS depot_type_check;
ALTER TABLE stock.warehouse DROP CONSTRAINT IF EXISTS warehouse_type_check;
ALTER TABLE stock.movement DROP CONSTRAINT IF EXISTS chk_transfert_destination;
ALTER TABLE stock.movement DROP CONSTRAINT IF EXISTS chk_transfer_destination;

-- 6. UPDATE STATUS VALUES — movement.type
UPDATE stock.movement SET type = 'entry' WHERE type = 'entree';
UPDATE stock.movement SET type = 'exit' WHERE type = 'sortie';
UPDATE stock.movement SET type = 'transfer' WHERE type = 'transfert';
UPDATE stock.movement SET type = 'inventory' WHERE type = 'inventaire';

-- 7. UPDATE STATUS VALUES — article.category
UPDATE stock.article SET category = 'wood' WHERE category = 'bois';
UPDATE stock.article SET category = 'hardware' WHERE category = 'quincaillerie';
UPDATE stock.article SET category = 'panel' WHERE category = 'panneau';
UPDATE stock.article SET category = 'insulation' WHERE category = 'isolant';
UPDATE stock.article SET category = 'finish' WHERE category = 'finition';
UPDATE stock.article SET category = 'other' WHERE category = 'autre';

-- 8. UPDATE STATUS VALUES — article.unit
UPDATE stock.article SET unit = 'ea' WHERE unit = 'u';

-- 9. UPDATE STATUS VALUES — warehouse.type
UPDATE stock.warehouse SET type = 'workshop' WHERE type = 'atelier';
UPDATE stock.warehouse SET type = 'job_site' WHERE type = 'chantier';
UPDATE stock.warehouse SET type = 'vehicle' WHERE type = 'vehicule';
UPDATE stock.warehouse SET type = 'storage' WHERE type = 'entrepot';

-- 10. ADD NEW CHECK CONSTRAINTS
ALTER TABLE stock.movement ADD CONSTRAINT movement_type_check
  CHECK (type IN ('entry','exit','transfer','inventory'));

ALTER TABLE stock.article ADD CONSTRAINT article_category_check
  CHECK (category IN ('wood','hardware','panel','insulation','finish','other'));

ALTER TABLE stock.article ADD CONSTRAINT article_unit_check
  CHECK (unit IN ('ea','m','m2','m3','kg','l'));

ALTER TABLE stock.warehouse ADD CONSTRAINT warehouse_type_check
  CHECK (type IN ('workshop','job_site','vehicle','storage'));

ALTER TABLE stock.movement ADD CONSTRAINT chk_transfer_destination
  CHECK (
    (type = 'transfer' AND destination_warehouse_id IS NOT NULL)
    OR (type <> 'transfer' AND destination_warehouse_id IS NULL)
  );

-- 11. RENAME INDEXES
ALTER INDEX IF EXISTS stock.idx_mouvement_tenant RENAME TO idx_movement_tenant;
ALTER INDEX IF EXISTS stock.idx_mouvement_article RENAME TO idx_movement_article;
ALTER INDEX IF EXISTS stock.idx_mouvement_depot RENAME TO idx_movement_warehouse;
ALTER INDEX IF EXISTS stock.idx_mouvement_date RENAME TO idx_movement_date;
ALTER INDEX IF EXISTS stock.idx_depot_tenant RENAME TO idx_warehouse_tenant;
ALTER INDEX IF EXISTS stock.idx_article_fournisseur RENAME TO idx_article_supplier;
ALTER INDEX IF EXISTS stock.idx_article_categorie RENAME TO idx_article_category;

-- 12. UPDATE RLS POLICIES (recreate with new table names)
DROP POLICY IF EXISTS tenant_isolation ON stock.warehouse;
CREATE POLICY tenant_isolation ON stock.warehouse
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON stock.movement;
CREATE POLICY tenant_isolation ON stock.movement
  USING (tenant_id = current_setting('app.tenant_id', true));
