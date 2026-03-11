-- Quote — DDL (Devis & Factures)

CREATE SCHEMA IF NOT EXISTS quote;
CREATE SCHEMA IF NOT EXISTS quote_ut;
CREATE SCHEMA IF NOT EXISTS quote_qa;
GRANT USAGE ON SCHEMA quote TO web_anon;

-- Devis
CREATE TABLE IF NOT EXISTS quote.devis (
  id serial PRIMARY KEY,
  numero text NOT NULL UNIQUE,                    -- DEV-2026-001
  client_id int NOT NULL REFERENCES crm.client(id) ON DELETE CASCADE,
  objet text NOT NULL,
  statut text NOT NULL DEFAULT 'brouillon'
    CHECK (statut IN ('brouillon', 'envoye', 'accepte', 'refuse')),
  notes text NOT NULL DEFAULT '',
  validite_jours int NOT NULL DEFAULT 30,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_devis_client ON quote.devis(client_id);
CREATE INDEX IF NOT EXISTS idx_devis_statut ON quote.devis(statut);

-- Factures
CREATE TABLE IF NOT EXISTS quote.facture (
  id serial PRIMARY KEY,
  numero text NOT NULL UNIQUE,                    -- FAC-2026-001
  client_id int NOT NULL REFERENCES crm.client(id) ON DELETE CASCADE,
  devis_id int REFERENCES quote.devis(id),        -- NULL = facture directe
  objet text NOT NULL,
  statut text NOT NULL DEFAULT 'brouillon'
    CHECK (statut IN ('brouillon', 'envoyee', 'payee')),
  notes text NOT NULL DEFAULT '',
  paid_at timestamptz,                             -- NULL = pas encore payee
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_facture_client ON quote.facture(client_id);
CREATE INDEX IF NOT EXISTS idx_facture_devis ON quote.facture(devis_id);
CREATE INDEX IF NOT EXISTS idx_facture_statut ON quote.facture(statut);

-- Lignes (partagees entre devis et factures, XOR constraint)
CREATE TABLE IF NOT EXISTS quote.ligne (
  id serial PRIMARY KEY,
  devis_id int REFERENCES quote.devis(id) ON DELETE CASCADE,
  facture_id int REFERENCES quote.facture(id) ON DELETE CASCADE,
  sort_order int NOT NULL DEFAULT 0,
  description text NOT NULL,
  quantite numeric(10,2) NOT NULL DEFAULT 1,
  unite text NOT NULL DEFAULT 'u',                 -- u, h, m, m2, m3, forfait
  prix_unitaire numeric(12,2) NOT NULL,
  tva_rate numeric(4,2) NOT NULL DEFAULT 20.00
    CHECK (tva_rate IN (0.00, 5.50, 10.00, 20.00)),
  CONSTRAINT ligne_parent_xor
    CHECK ((devis_id IS NOT NULL AND facture_id IS NULL)
        OR (devis_id IS NULL AND facture_id IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_ligne_devis ON quote.ligne(devis_id);
CREATE INDEX IF NOT EXISTS idx_ligne_facture ON quote.ligne(facture_id);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION quote._set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_devis_updated_at ON quote.devis;
CREATE TRIGGER trg_devis_updated_at
  BEFORE UPDATE ON quote.devis
  FOR EACH ROW EXECUTE FUNCTION quote._set_updated_at();

DROP TRIGGER IF EXISTS trg_facture_updated_at ON quote.facture;
CREATE TRIGGER trg_facture_updated_at
  BEFORE UPDATE ON quote.facture
  FOR EACH ROW EXECUTE FUNCTION quote._set_updated_at();

-- Permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON quote.devis TO web_anon;
GRANT USAGE ON SEQUENCE quote.devis_id_seq TO web_anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON quote.facture TO web_anon;
GRANT USAGE ON SEQUENCE quote.facture_id_seq TO web_anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON quote.ligne TO web_anon;
GRANT USAGE ON SEQUENCE quote.ligne_id_seq TO web_anon;

GRANT USAGE ON SCHEMA quote_ut TO web_anon;
GRANT USAGE ON SCHEMA quote_qa TO web_anon;

-- Default privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA quote GRANT EXECUTE ON FUNCTIONS TO web_anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA quote_ut GRANT EXECUTE ON FUNCTIONS TO web_anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA quote_qa GRANT EXECUTE ON FUNCTIONS TO web_anon;
