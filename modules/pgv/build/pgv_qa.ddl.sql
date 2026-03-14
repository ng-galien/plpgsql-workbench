-- pgv_qa: pgView component showcase (DDL + seed data)
-- QA schema exercising all pgv primitives in real pages

CREATE SCHEMA IF NOT EXISTS pgv_qa;

CREATE TABLE IF NOT EXISTS pgv_qa.setting (
  key        text PRIMARY KEY,
  value      text NOT NULL,
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pgv_qa.item (
  id         serial PRIMARY KEY,
  name       text NOT NULL,
  status     text NOT NULL DEFAULT 'draft',
  created_at timestamptz DEFAULT now()
);

GRANT USAGE ON SCHEMA pgv_qa TO anon;
GRANT SELECT, INSERT, UPDATE ON pgv_qa.setting TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON pgv_qa.item TO anon;
GRANT USAGE ON SEQUENCE pgv_qa.item_id_seq TO anon;

INSERT INTO pgv_qa.item (name, status) VALUES
  ('Premier document', 'draft'),
  ('Facture Mars', 'classified'),
  ('Contrat bail', 'archived'),
  ('Releve bancaire', 'draft'),
  ('Attestation', 'classified');

-- FTS demo: product catalog
CREATE TABLE IF NOT EXISTS pgv_qa.product (
  id          serial PRIMARY KEY,
  name        text NOT NULL,
  description text,
  category    text,
  price       numeric(10,2),
  status      text DEFAULT 'active',
  search_vec  tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('pgv_search', coalesce(name,'')), 'A') ||
    setweight(to_tsvector('pgv_search', coalesce(description,'')), 'B')
  ) STORED
);
CREATE INDEX IF NOT EXISTS idx_qa_product_search ON pgv_qa.product USING GIN(search_vec);

GRANT SELECT, INSERT, UPDATE, DELETE ON pgv_qa.product TO anon;
GRANT USAGE ON SEQUENCE pgv_qa.product_id_seq TO anon;

INSERT INTO pgv_qa.product (name, description, category, price, status) VALUES
  ('Poutre chêne massif 200x80', 'Structure bois pour charpente traditionnelle', 'bois', 89.90, 'active'),
  ('Vis à bois inox 6x80', 'Fixation pour assemblage de pièces en bois dur', 'quincaillerie', 12.50, 'active'),
  ('Planche de coffrage sapin', 'Coffrage béton, réutilisable 3 fois minimum', 'bois', 8.75, 'active'),
  ('Colle polyuréthane D4', 'Collage structural extérieur, résistant à l''eau', 'chimie', 24.00, 'active'),
  ('Équerre renforcée 90°', 'Assemblage charpente, acier galvanisé', 'quincaillerie', 3.40, 'active'),
  ('Panneau OSB3 250x125', 'Panneau structurel pour murs et planchers', 'panneau', 18.60, 'active'),
  ('Lame de terrasse pin traité', 'Classe 4, traitement autoclave vert', 'bois', 6.20, 'active'),
  ('Tirefond M10x200', 'Fixation lourde pour bois et maçonnerie', 'quincaillerie', 1.85, 'active'),
  ('Isolant fibre de bois 140mm', 'Isolation thermique et phonique, lambda 0.038', 'isolation', 32.00, 'active'),
  ('Pare-pluie HPV', 'Écran sous-toiture haute perméabilité vapeur', 'isolation', 55.00, 'active'),
  ('Madrier épicéa 75x225', 'Bois de structure séché, classé C24', 'bois', 45.50, 'active'),
  ('Sabots de charpente', 'Connecteur métallique pour solivage', 'quincaillerie', 2.90, 'active'),
  ('Lasure bois extérieur chêne', 'Protection UV et intempéries, 10 ans', 'chimie', 38.00, 'active'),
  ('Clou annelé galvanisé 90mm', 'Fixation bardage et voligeage', 'quincaillerie', 15.00, 'active'),
  ('Bastaing sapin 63x175', 'Charpente industrielle, séchage artificiel', 'bois', 28.00, 'active'),
  ('Membrane d''étanchéité EPDM', 'Toiture plate, durée de vie 50 ans', 'isolation', 22.50, 'active'),
  ('Boulon de charpente M12x160', 'Assemblage poutre-poteau, classe 8.8', 'quincaillerie', 4.20, 'active'),
  ('Contreplaqué marine 18mm', 'Okoumé face/contreface, colle WBP', 'panneau', 52.00, 'active'),
  ('Chevron raboté 60x80', 'Toiture et ossature, abouté collé', 'bois', 12.80, 'discontinued'),
  ('Mousse expansive PU', 'Calfeutrement et isolation des joints', 'chimie', 9.50, 'discontinued')
ON CONFLICT DO NOTHING;
