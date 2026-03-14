-- stock — DDL

CREATE SCHEMA IF NOT EXISTS stock;
CREATE SCHEMA IF NOT EXISTS stock_ut;
CREATE SCHEMA IF NOT EXISTS stock_qa;

-- Articles (catalogue matériaux/fournitures)
CREATE TABLE IF NOT EXISTS stock.article (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  reference text NOT NULL,
  designation text NOT NULL,
  categorie text NOT NULL CHECK (categorie IN ('bois','quincaillerie','panneau','isolant','finition','autre')),
  unite text NOT NULL DEFAULT 'u' CHECK (unite IN ('u','m','m2','m3','kg','l')),
  prix_achat numeric(12,2),
  pmp numeric(12,4) DEFAULT 0,
  seuil_mini numeric(10,2) NOT NULL DEFAULT 0,
  fournisseur_id int REFERENCES crm.client(id),
  notes text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE stock.article ADD COLUMN IF NOT EXISTS tenant_id text NOT NULL DEFAULT '';
ALTER TABLE stock.article ALTER COLUMN tenant_id SET DEFAULT current_setting('app.tenant_id', true);

CREATE UNIQUE INDEX IF NOT EXISTS idx_article_tenant_ref ON stock.article(tenant_id, reference);
CREATE INDEX IF NOT EXISTS idx_article_tenant ON stock.article(tenant_id);
CREATE INDEX IF NOT EXISTS idx_article_categorie ON stock.article(categorie);
CREATE INDEX IF NOT EXISTS idx_article_fournisseur ON stock.article(fournisseur_id);

-- Dépôts (emplacements de stockage)
CREATE TABLE IF NOT EXISTS stock.depot (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  nom text NOT NULL,
  type text NOT NULL CHECK (type IN ('atelier','chantier','vehicule','entrepot')),
  adresse text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE stock.depot ADD COLUMN IF NOT EXISTS tenant_id text NOT NULL DEFAULT '';
ALTER TABLE stock.depot ALTER COLUMN tenant_id SET DEFAULT current_setting('app.tenant_id', true);

CREATE INDEX IF NOT EXISTS idx_depot_tenant ON stock.depot(tenant_id);

-- Mouvements (journal INSERT-ONLY — jamais UPDATE/DELETE)
CREATE TABLE IF NOT EXISTS stock.mouvement (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  article_id int NOT NULL REFERENCES stock.article(id),
  depot_id int NOT NULL REFERENCES stock.depot(id),
  type text NOT NULL CHECK (type IN ('entree','sortie','transfert','inventaire')),
  quantite numeric(10,2) NOT NULL,
  prix_unitaire numeric(12,4),
  reference text,
  depot_destination_id int REFERENCES stock.depot(id),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE stock.mouvement ADD COLUMN IF NOT EXISTS tenant_id text NOT NULL DEFAULT '';
ALTER TABLE stock.mouvement ALTER COLUMN tenant_id SET DEFAULT current_setting('app.tenant_id', true);

-- Contraintes métier
ALTER TABLE stock.mouvement DROP CONSTRAINT IF EXISTS chk_transfert_destination;
ALTER TABLE stock.mouvement ADD CONSTRAINT chk_transfert_destination
  CHECK (
    (type = 'transfert' AND depot_destination_id IS NOT NULL)
    OR (type <> 'transfert' AND depot_destination_id IS NULL)
  );

CREATE INDEX IF NOT EXISTS idx_mouvement_tenant ON stock.mouvement(tenant_id);
CREATE INDEX IF NOT EXISTS idx_mouvement_article ON stock.mouvement(article_id);
CREATE INDEX IF NOT EXISTS idx_mouvement_depot ON stock.mouvement(depot_id);
CREATE INDEX IF NOT EXISTS idx_mouvement_date ON stock.mouvement(created_at DESC);

-- Row Level Security
ALTER TABLE stock.article ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock.depot ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock.mouvement ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation ON stock.article;
CREATE POLICY tenant_isolation ON stock.article
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON stock.depot;
CREATE POLICY tenant_isolation ON stock.depot
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON stock.mouvement;
CREATE POLICY tenant_isolation ON stock.mouvement
  USING (tenant_id = current_setting('app.tenant_id', true));

-- Lien vers catalog (soft FK — catalog peut ne pas être déployé)
ALTER TABLE stock.article ADD COLUMN IF NOT EXISTS catalog_article_id integer;
CREATE INDEX IF NOT EXISTS idx_article_catalog ON stock.article(catalog_article_id);
