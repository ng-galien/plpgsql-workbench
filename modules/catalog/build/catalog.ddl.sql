-- catalog — DDL

CREATE SCHEMA IF NOT EXISTS catalog;
CREATE SCHEMA IF NOT EXISTS catalog_ut;
CREATE SCHEMA IF NOT EXISTS catalog_qa;

-- Rename migration (idempotent: only runs if old names exist)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'catalog' AND tablename = 'categorie') THEN
    ALTER TABLE catalog.categorie RENAME TO category;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'catalog' AND tablename = 'unite') THEN
    ALTER TABLE catalog.unite RENAME TO unit;
  END IF;
  -- Column renames on category
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalog' AND table_name = 'category' AND column_name = 'nom') THEN
    ALTER TABLE catalog.category RENAME COLUMN nom TO name;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalog' AND table_name = 'category' AND column_name = 'ordre') THEN
    ALTER TABLE catalog.category RENAME COLUMN ordre TO sort_order;
  END IF;
  -- Column renames on article
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalog' AND table_name = 'article' AND column_name = 'designation') THEN
    ALTER TABLE catalog.article RENAME COLUMN designation TO name;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalog' AND table_name = 'article' AND column_name = 'categorie_id') THEN
    ALTER TABLE catalog.article RENAME COLUMN categorie_id TO category_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalog' AND table_name = 'article' AND column_name = 'unite') THEN
    ALTER TABLE catalog.article RENAME COLUMN unite TO unit;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalog' AND table_name = 'article' AND column_name = 'prix_vente') THEN
    ALTER TABLE catalog.article RENAME COLUMN prix_vente TO sale_price;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalog' AND table_name = 'article' AND column_name = 'prix_achat') THEN
    ALTER TABLE catalog.article RENAME COLUMN prix_achat TO purchase_price;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalog' AND table_name = 'article' AND column_name = 'tva') THEN
    ALTER TABLE catalog.article RENAME COLUMN tva TO vat_rate;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'catalog' AND table_name = 'article' AND column_name = 'actif') THEN
    ALTER TABLE catalog.article RENAME COLUMN actif TO active;
  END IF;
END $$;

-- Categories (tree structure)
CREATE TABLE IF NOT EXISTS catalog.category (
  id serial PRIMARY KEY,
  name text NOT NULL,
  parent_id integer REFERENCES catalog.category(id) ON DELETE SET NULL,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Units of measure
CREATE TABLE IF NOT EXISTS catalog.unit (
  code text PRIMARY KEY,
  label text NOT NULL
);

-- Articles / services
CREATE TABLE IF NOT EXISTS catalog.article (
  id serial PRIMARY KEY,
  reference text UNIQUE,
  name text NOT NULL,
  description text,
  category_id integer REFERENCES catalog.category(id) ON DELETE SET NULL,
  unit text REFERENCES catalog.unit(code) DEFAULT 'u',
  sale_price numeric(12,2),
  purchase_price numeric(12,2),
  vat_rate numeric(4,2) DEFAULT 20.00,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Search indexes
CREATE INDEX IF NOT EXISTS idx_article_name ON catalog.article USING gin (to_tsvector('french', name));
CREATE INDEX IF NOT EXISTS idx_article_category ON catalog.article(category_id);
CREATE INDEX IF NOT EXISTS idx_article_reference ON catalog.article(reference);

-- Grants: SELECT only, no DML for anon
GRANT USAGE ON SCHEMA catalog TO anon;
GRANT USAGE ON SCHEMA catalog_ut TO anon;
GRANT USAGE ON SCHEMA catalog_qa TO anon;
GRANT SELECT ON ALL TABLES IN SCHEMA catalog TO anon;
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA catalog FROM anon;
