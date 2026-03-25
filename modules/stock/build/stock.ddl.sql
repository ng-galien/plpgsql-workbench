-- stock — DDL (English)

CREATE SCHEMA IF NOT EXISTS stock;
CREATE SCHEMA IF NOT EXISTS stock_ut;
CREATE SCHEMA IF NOT EXISTS stock_qa;

-- Articles (inventory items)
CREATE TABLE IF NOT EXISTS stock.article (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  reference text NOT NULL,
  description text NOT NULL,
  category text NOT NULL CHECK (category IN ('wood','hardware','panel','insulation','finish','other')),
  unit text NOT NULL DEFAULT 'ea' CHECK (unit IN ('ea','m','m2','m3','kg','l')),
  purchase_price numeric(12,2),
  wap numeric(12,4) DEFAULT 0,
  min_threshold numeric(10,2) NOT NULL DEFAULT 0,
  supplier_id int REFERENCES crm.client(id),
  notes text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  catalog_article_id integer
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_article_tenant_ref ON stock.article(tenant_id, reference);
CREATE INDEX IF NOT EXISTS idx_article_tenant ON stock.article(tenant_id);
CREATE INDEX IF NOT EXISTS idx_article_category ON stock.article(category);
CREATE INDEX IF NOT EXISTS idx_article_supplier ON stock.article(supplier_id);
CREATE INDEX IF NOT EXISTS idx_article_catalog ON stock.article(catalog_article_id);

-- Warehouses (storage locations)
CREATE TABLE IF NOT EXISTS stock.warehouse (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  name text NOT NULL,
  type text NOT NULL CHECK (type IN ('workshop','job_site','vehicle','storage')),
  address text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_warehouse_tenant ON stock.warehouse(tenant_id);

-- Movements (INSERT-ONLY journal — never UPDATE/DELETE)
CREATE TABLE IF NOT EXISTS stock.movement (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  article_id int NOT NULL REFERENCES stock.article(id),
  warehouse_id int NOT NULL REFERENCES stock.warehouse(id),
  type text NOT NULL CHECK (type IN ('entry','exit','transfer','inventory')),
  quantity numeric(10,2) NOT NULL,
  unit_price numeric(12,4),
  reference text,
  destination_warehouse_id int REFERENCES stock.warehouse(id),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Business constraints
ALTER TABLE stock.movement DROP CONSTRAINT IF EXISTS chk_transfer_destination;
ALTER TABLE stock.movement ADD CONSTRAINT chk_transfer_destination
  CHECK (
    (type = 'transfer' AND destination_warehouse_id IS NOT NULL)
    OR (type <> 'transfer' AND destination_warehouse_id IS NULL)
  );

CREATE INDEX IF NOT EXISTS idx_movement_tenant ON stock.movement(tenant_id);
CREATE INDEX IF NOT EXISTS idx_movement_article ON stock.movement(article_id);
CREATE INDEX IF NOT EXISTS idx_movement_warehouse ON stock.movement(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_movement_date ON stock.movement(created_at DESC);

-- Row Level Security
ALTER TABLE stock.article ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock.warehouse ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock.movement ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation ON stock.article;
CREATE POLICY tenant_isolation ON stock.article
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON stock.warehouse;
CREATE POLICY tenant_isolation ON stock.warehouse
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON stock.movement;
CREATE POLICY tenant_isolation ON stock.movement
  USING (tenant_id = current_setting('app.tenant_id', true));
