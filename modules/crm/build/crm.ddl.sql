-- CRM — DDL

CREATE SCHEMA IF NOT EXISTS crm;
CREATE SCHEMA IF NOT EXISTS crm_ut;
CREATE SCHEMA IF NOT EXISTS crm_qa;
GRANT USAGE ON SCHEMA crm TO web_anon;

-- Clients (particuliers et entreprises)
CREATE TABLE IF NOT EXISTS crm.client (
  id serial PRIMARY KEY,
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

CREATE INDEX IF NOT EXISTS idx_client_active_name ON crm.client(active, name);
CREATE INDEX IF NOT EXISTS idx_client_tags ON crm.client USING gin(tags);

-- Contacts secondaires (entreprises)
CREATE TABLE IF NOT EXISTS crm.contact (
  id serial PRIMARY KEY,
  client_id int NOT NULL REFERENCES crm.client(id) ON DELETE CASCADE,
  name text NOT NULL,
  role text NOT NULL DEFAULT '',           -- vide si inconnu
  email text,                              -- NULL = pas d'email
  phone text,                              -- NULL = pas de téléphone
  is_primary boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_contact_client ON crm.contact(client_id);

-- Interactions (historique — PAS devis/factures, bounded context séparé)
CREATE TABLE IF NOT EXISTS crm.interaction (
  id serial PRIMARY KEY,
  client_id int NOT NULL REFERENCES crm.client(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('call', 'visit', 'email', 'note')),
  subject text NOT NULL,
  body text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_interaction_client_date ON crm.interaction(client_id, created_at DESC);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION crm._set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_client_updated_at ON crm.client;
CREATE TRIGGER trg_client_updated_at
  BEFORE UPDATE ON crm.client
  FOR EACH ROW EXECUTE FUNCTION crm._set_updated_at();

-- Permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON crm.client TO web_anon;
GRANT USAGE ON SEQUENCE crm.client_id_seq TO web_anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON crm.contact TO web_anon;
GRANT USAGE ON SEQUENCE crm.contact_id_seq TO web_anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON crm.interaction TO web_anon;
GRANT USAGE ON SEQUENCE crm.interaction_id_seq TO web_anon;

GRANT USAGE ON SCHEMA crm_ut TO web_anon;
GRANT USAGE ON SCHEMA crm_qa TO web_anon;

-- Default privileges pour les fonctions créées après le DDL
ALTER DEFAULT PRIVILEGES IN SCHEMA crm GRANT EXECUTE ON FUNCTIONS TO web_anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA crm_ut GRANT EXECUTE ON FUNCTIONS TO web_anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA crm_qa GRANT EXECUTE ON FUNCTIONS TO web_anon;
