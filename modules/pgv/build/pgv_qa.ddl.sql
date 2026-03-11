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

GRANT USAGE ON SCHEMA pgv_qa TO web_anon;
GRANT SELECT, INSERT, UPDATE ON pgv_qa.setting TO web_anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON pgv_qa.item TO web_anon;
GRANT USAGE ON SEQUENCE pgv_qa.item_id_seq TO web_anon;

INSERT INTO pgv_qa.item (name, status) VALUES
  ('Premier document', 'draft'),
  ('Facture Mars', 'classified'),
  ('Contrat bail', 'archived'),
  ('Releve bancaire', 'draft'),
  ('Attestation', 'classified');
