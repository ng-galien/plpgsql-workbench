-- expense — DDL

CREATE SCHEMA IF NOT EXISTS expense;
CREATE SCHEMA IF NOT EXISTS expense_ut;
CREATE SCHEMA IF NOT EXISTS expense_qa;

-- Catégories de frais
CREATE TABLE IF NOT EXISTS expense.categorie (
  id serial PRIMARY KEY,
  nom text NOT NULL,
  code_comptable text,        -- lien vers ledger.compte si disponible
  created_at timestamptz DEFAULT now()
);

-- Notes de frais (regroupement)
CREATE TABLE IF NOT EXISTS expense.note (
  id serial PRIMARY KEY,
  reference text UNIQUE,       -- NDF-2026-001
  auteur text NOT NULL,        -- nom du salarié/artisan
  date_debut date NOT NULL,
  date_fin date NOT NULL,
  statut text NOT NULL DEFAULT 'brouillon' CHECK (statut IN ('brouillon', 'soumise', 'validee', 'remboursee', 'rejetee')),
  commentaire text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Lignes de frais
CREATE TABLE IF NOT EXISTS expense.ligne (
  id serial PRIMARY KEY,
  note_id integer NOT NULL REFERENCES expense.note(id) ON DELETE CASCADE,
  date_depense date NOT NULL,
  categorie_id integer REFERENCES expense.categorie(id),
  description text NOT NULL,
  montant_ht numeric(12,2) NOT NULL,
  tva numeric(12,2) DEFAULT 0,
  montant_ttc numeric(12,2) GENERATED ALWAYS AS (montant_ht + tva) STORED,
  justificatif text,           -- référence document/photo
  km numeric(8,1),             -- si déplacement
  created_at timestamptz DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_note_statut ON expense.note(statut);
CREATE INDEX IF NOT EXISTS idx_note_auteur ON expense.note(auteur);
CREATE INDEX IF NOT EXISTS idx_ligne_note ON expense.ligne(note_id);
CREATE INDEX IF NOT EXISTS idx_ligne_date ON expense.ligne(date_depense);

-- Grants
GRANT USAGE ON SCHEMA expense TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA expense TO anon;
GRANT SELECT ON ALL TABLES IN SCHEMA expense TO anon;
GRANT USAGE ON SCHEMA expense_ut TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA expense_ut TO anon;
GRANT USAGE ON SCHEMA expense_qa TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA expense_qa TO anon;

-- Catégories par défaut
INSERT INTO expense.categorie (nom, code_comptable) VALUES
  ('Déplacement véhicule', '625100'),
  ('Transport (train, avion)', '625200'),
  ('Hébergement', '625600'),
  ('Repas', '625700'),
  ('Fournitures', '606400'),
  ('Outillage', '606300'),
  ('Téléphone/Internet', '626000'),
  ('Divers', '625800')
ON CONFLICT DO NOTHING;
