-- Quote — DDL (Devis & Factures)
-- Structure only: tables, indexes, constraints, RLS policies.
-- No GRANT (pg_pack), no CREATE FUNCTION (pg_func_set), no INSERT (quote.seed.sql).

CREATE SCHEMA IF NOT EXISTS quote;
CREATE SCHEMA IF NOT EXISTS quote_ut;
CREATE SCHEMA IF NOT EXISTS quote_qa;

-- Devis
CREATE TABLE IF NOT EXISTS quote.devis (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
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
CREATE INDEX IF NOT EXISTS idx_devis_tenant ON quote.devis(tenant_id);

-- Factures
CREATE TABLE IF NOT EXISTS quote.facture (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  numero text NOT NULL UNIQUE,                    -- FAC-2026-001
  client_id int NOT NULL REFERENCES crm.client(id) ON DELETE CASCADE,
  devis_id int REFERENCES quote.devis(id),        -- NULL = facture directe
  objet text NOT NULL,
  statut text NOT NULL DEFAULT 'brouillon'
    CHECK (statut IN ('brouillon', 'envoyee', 'payee', 'relance')),
  notes text NOT NULL DEFAULT '',
  paid_at timestamptz,                             -- NULL = pas encore payee
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_facture_client ON quote.facture(client_id);
CREATE INDEX IF NOT EXISTS idx_facture_devis ON quote.facture(devis_id);
CREATE INDEX IF NOT EXISTS idx_facture_statut ON quote.facture(statut);
CREATE INDEX IF NOT EXISTS idx_facture_tenant ON quote.facture(tenant_id);

-- Lignes (partagees entre devis et factures, XOR constraint)
CREATE TABLE IF NOT EXISTS quote.ligne (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
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
CREATE INDEX IF NOT EXISTS idx_ligne_tenant ON quote.ligne(tenant_id);

-- Mentions legales (conditions, penalites retard, etc.)
CREATE TABLE IF NOT EXISTS quote.mention (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  label text NOT NULL,
  texte text NOT NULL,
  active boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_mention_tenant ON quote.mention(tenant_id);

-- RLS
ALTER TABLE quote.devis ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON quote.devis
  USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE quote.facture ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON quote.facture
  USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE quote.ligne ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON quote.ligne
  USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE quote.mention ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON quote.mention
  USING (tenant_id = current_setting('app.tenant_id', true));
