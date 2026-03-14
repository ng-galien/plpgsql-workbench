-- CRM — DDL

CREATE SCHEMA IF NOT EXISTS crm;
CREATE SCHEMA IF NOT EXISTS crm_ut;
CREATE SCHEMA IF NOT EXISTS crm_qa;
GRANT USAGE ON SCHEMA crm TO anon;

-- Clients (particuliers et entreprises)
CREATE TABLE IF NOT EXISTS crm.client (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  type text NOT NULL CHECK (type IN ('individual', 'company')),
  name text NOT NULL,
  email text,                              -- NULL = pas d'email connu
  phone text,                              -- NULL = pas de téléphone connu
  address text,                            -- NULL = adresse inconnue
  city text,                               -- NULL = ville inconnue
  postal_code text,                        -- NULL = CP inconnu
  tier text NOT NULL DEFAULT 'standard' CHECK (tier IN ('standard', 'premium', 'vip')),
  tags text[] NOT NULL DEFAULT '{}',
  notes text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE crm.client ADD COLUMN IF NOT EXISTS tenant_id text NOT NULL DEFAULT '';
ALTER TABLE crm.client ALTER COLUMN tenant_id SET DEFAULT current_setting('app.tenant_id', true);

CREATE INDEX IF NOT EXISTS idx_client_tenant ON crm.client(tenant_id);
CREATE INDEX IF NOT EXISTS idx_client_active_name ON crm.client(active, name);
CREATE INDEX IF NOT EXISTS idx_client_tags ON crm.client USING gin(tags);

-- Contacts secondaires (entreprises)
CREATE TABLE IF NOT EXISTS crm.contact (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  client_id int NOT NULL REFERENCES crm.client(id) ON DELETE CASCADE,
  name text NOT NULL,
  role text NOT NULL DEFAULT '',           -- vide si inconnu
  email text,                              -- NULL = pas d'email
  phone text,                              -- NULL = pas de téléphone
  is_primary boolean NOT NULL DEFAULT false
);

-- Migration: add tenant_id to existing tables (idempotent)
ALTER TABLE crm.contact ADD COLUMN IF NOT EXISTS tenant_id text NOT NULL DEFAULT '';
ALTER TABLE crm.contact ALTER COLUMN tenant_id SET DEFAULT current_setting('app.tenant_id', true);

CREATE INDEX IF NOT EXISTS idx_contact_tenant ON crm.contact(tenant_id);
CREATE INDEX IF NOT EXISTS idx_contact_client ON crm.contact(client_id);

-- Interactions (historique — PAS devis/factures, bounded context séparé)
CREATE TABLE IF NOT EXISTS crm.interaction (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  client_id int NOT NULL REFERENCES crm.client(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('call', 'visit', 'email', 'note')),
  subject text NOT NULL,
  body text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE crm.interaction ADD COLUMN IF NOT EXISTS tenant_id text NOT NULL DEFAULT '';
ALTER TABLE crm.interaction ALTER COLUMN tenant_id SET DEFAULT current_setting('app.tenant_id', true);

CREATE INDEX IF NOT EXISTS idx_interaction_tenant ON crm.interaction(tenant_id);
CREATE INDEX IF NOT EXISTS idx_interaction_client_date ON crm.interaction(client_id, created_at DESC);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION crm._set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;


-- Row Level Security
ALTER TABLE crm.client ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.contact ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm.interaction ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation ON crm.client;
CREATE POLICY tenant_isolation ON crm.client
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON crm.contact;
CREATE POLICY tenant_isolation ON crm.contact
  USING (tenant_id = current_setting('app.tenant_id', true));
DROP POLICY IF EXISTS tenant_isolation ON crm.interaction;
CREATE POLICY tenant_isolation ON crm.interaction
  USING (tenant_id = current_setting('app.tenant_id', true));

-- Permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON crm.client TO anon;
GRANT USAGE ON SEQUENCE crm.client_id_seq TO anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON crm.contact TO anon;
GRANT USAGE ON SEQUENCE crm.contact_id_seq TO anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON crm.interaction TO anon;
GRANT USAGE ON SEQUENCE crm.interaction_id_seq TO anon;

GRANT USAGE ON SCHEMA crm_ut TO anon;
GRANT USAGE ON SCHEMA crm_qa TO anon;

-- Default privileges pour les fonctions créées après le DDL
ALTER DEFAULT PRIVILEGES IN SCHEMA crm GRANT EXECUTE ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA crm_ut GRANT EXECUTE ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA crm_qa GRANT EXECUTE ON FUNCTIONS TO anon;
