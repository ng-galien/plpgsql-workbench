-- Bootstrap workbench schema — tables and functions are managed by modules/workbench/
-- This seed only creates the schema and inserts initial data needed before module deploy.

CREATE SCHEMA IF NOT EXISTS workbench;

-- Minimal tables needed for dev seed (full DDL in modules/workbench/build/workbench.ddl.sql)
CREATE TABLE IF NOT EXISTS workbench.toolbox (
  name TEXT PRIMARY KEY,
  description TEXT
);

CREATE TABLE IF NOT EXISTS workbench.tenant (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE,
  plan TEXT NOT NULL DEFAULT 'solo' CHECK (plan IN ('solo','pro','equipe')),
  toolbox_name TEXT REFERENCES workbench.toolbox(name),
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workbench.tenant_module (
  tenant_id   TEXT NOT NULL REFERENCES workbench.tenant(id) ON DELETE CASCADE,
  module      TEXT NOT NULL,
  active      BOOLEAN NOT NULL DEFAULT true,
  sort_order  INTEGER NOT NULL DEFAULT 50,
  activated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, module)
);

-- Dev seed data
INSERT INTO workbench.tenant (id, name, slug, plan)
VALUES ('dev', 'Dev Workbench', 'dev', 'equipe')
ON CONFLICT (id) DO NOTHING;

INSERT INTO workbench.tenant_module (tenant_id, module, sort_order) VALUES
  ('dev', 'pgv',       0),
  ('dev', 'workbench', 5),
  ('dev', 'ops',       8),
  ('dev', 'crm',      10),
  ('dev', 'quote',    15),
  ('dev', 'project',  20),
  ('dev', 'planning', 25),
  ('dev', 'cad',      30),
  ('dev', 'purchase', 40),
  ('dev', 'stock',    50),
  ('dev', 'ledger',   60),
  ('dev', 'hr',       80)
ON CONFLICT DO NOTHING;
