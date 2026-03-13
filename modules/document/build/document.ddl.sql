-- document — DDL

CREATE SCHEMA IF NOT EXISTS document;
CREATE SCHEMA IF NOT EXISTS document_ut;
CREATE SCHEMA IF NOT EXISTS document_qa;

-- Infos émetteur (entreprise) — pré-requis bloquant pour factures/devis
CREATE TABLE IF NOT EXISTS document.company (
  id          SERIAL PRIMARY KEY,
  tenant_id   TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
  name        TEXT NOT NULL,
  siret       TEXT,
  tva_intra   TEXT,
  address     TEXT,
  city        TEXT,
  postal_code TEXT,
  phone       TEXT,
  email       TEXT,
  website     TEXT,
  logo_asset_id UUID,
  mentions    TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (tenant_id)
);

-- Add unique constraint if missing (idempotent re-apply)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'company_tenant_id_key' AND conrelid = 'document.company'::regclass) THEN
    ALTER TABLE document.company ADD UNIQUE (tenant_id);
  END IF;
END $$;

-- Templates de documents (designés via illustrator)
CREATE TABLE IF NOT EXISTS document.template (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
  name        TEXT NOT NULL,
  doc_type    TEXT NOT NULL,
  format      TEXT NOT NULL DEFAULT 'A4',
  orientation TEXT NOT NULL DEFAULT 'portrait',
  canvas      JSONB NOT NULL DEFAULT '{}',
  layout      JSONB NOT NULL DEFAULT '[]',
  is_default  BOOLEAN DEFAULT false,
  version     INTEGER DEFAULT 1,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

-- Documents générés (instance template + données)
CREATE TABLE IF NOT EXISTS document.document (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
  template_id UUID REFERENCES document.template(id),
  doc_type    TEXT NOT NULL,
  ref_module  TEXT,
  ref_id      TEXT,
  title       TEXT NOT NULL,
  data        JSONB DEFAULT '{}',
  status      TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'generated', 'signed', 'archived')),
  pdf_path    TEXT,
  svg_content TEXT,
  generated_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_doc_tenant ON document.document(tenant_id);
CREATE INDEX IF NOT EXISTS idx_doc_type ON document.document(tenant_id, doc_type);
CREATE INDEX IF NOT EXISTS idx_doc_ref ON document.document(ref_module, ref_id);
CREATE INDEX IF NOT EXISTS idx_tpl_tenant ON document.template(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tpl_type ON document.template(tenant_id, doc_type);

-- Grants
GRANT USAGE ON SCHEMA document TO web_anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA document TO web_anon;
GRANT SELECT ON ALL TABLES IN SCHEMA document TO web_anon;

GRANT USAGE ON SCHEMA document_ut TO web_anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA document_ut TO web_anon;

GRANT USAGE ON SCHEMA document_qa TO web_anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA document_qa TO web_anon;
