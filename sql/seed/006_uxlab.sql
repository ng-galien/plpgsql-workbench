-- UX Lab: standalone pgView app for UI/UX pattern validation
-- Zero dependencies on docman/docstore

CREATE SCHEMA IF NOT EXISTS uxlab;
GRANT USAGE ON SCHEMA uxlab TO web_anon;

-- Simple settings table
CREATE TABLE IF NOT EXISTS uxlab.setting (
  key        text PRIMARY KEY,
  value      text NOT NULL,
  updated_at timestamptz DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE ON uxlab.setting TO web_anon;

-- Sample data for testing
CREATE TABLE IF NOT EXISTS uxlab.item (
  id    serial PRIMARY KEY,
  name  text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  created_at timestamptz DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON uxlab.item TO web_anon;
GRANT USAGE ON SEQUENCE uxlab.item_id_seq TO web_anon;

INSERT INTO uxlab.item (name, status) VALUES
  ('Premier document', 'draft'),
  ('Facture Mars', 'classified'),
  ('Contrat bail', 'archived'),
  ('Releve bancaire', 'draft'),
  ('Attestation', 'classified')
ON CONFLICT DO NOTHING;
