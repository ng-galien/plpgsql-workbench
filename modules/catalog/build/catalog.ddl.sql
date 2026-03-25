-- catalog — DDL

CREATE SCHEMA IF NOT EXISTS catalog;
CREATE SCHEMA IF NOT EXISTS catalog_ut;
CREATE SCHEMA IF NOT EXISTS catalog_qa;

-- Catégories (arborescence simple)
CREATE TABLE IF NOT EXISTS catalog.categorie (
  id serial PRIMARY KEY,
  nom text NOT NULL,
  parent_id integer REFERENCES catalog.categorie(id) ON DELETE SET NULL,
  ordre integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Unités de mesure
CREATE TABLE IF NOT EXISTS catalog.unite (
  code text PRIMARY KEY,  -- m, m2, m3, kg, h, u, l, ml, forfait
  label text NOT NULL
);

-- Articles / prestations
CREATE TABLE IF NOT EXISTS catalog.article (
  id serial PRIMARY KEY,
  reference text UNIQUE,           -- code interne (ex: PLQ-001)
  designation text NOT NULL,       -- nom affiché
  description text,                -- détail libre
  categorie_id integer REFERENCES catalog.categorie(id) ON DELETE SET NULL,
  unite text REFERENCES catalog.unite(code) DEFAULT 'u',
  prix_vente numeric(12,2),        -- HT
  prix_achat numeric(12,2),        -- HT fournisseur
  tva numeric(4,2) DEFAULT 20.00,  -- taux TVA %
  actif boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index recherche
CREATE INDEX IF NOT EXISTS idx_article_designation ON catalog.article USING gin (to_tsvector('french', designation));
CREATE INDEX IF NOT EXISTS idx_article_categorie ON catalog.article(categorie_id);
CREATE INDEX IF NOT EXISTS idx_article_reference ON catalog.article(reference);

-- Grants: SELECT only, no DML for anon
GRANT USAGE ON SCHEMA catalog TO anon;
GRANT USAGE ON SCHEMA catalog_ut TO anon;
GRANT USAGE ON SCHEMA catalog_qa TO anon;
GRANT SELECT ON ALL TABLES IN SCHEMA catalog TO anon;
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA catalog FROM anon;

