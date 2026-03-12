-- Add tenant_id + RLS to all quote tables

ALTER TABLE quote.devis ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'dev';
ALTER TABLE quote.facture ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'dev';
ALTER TABLE quote.ligne ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'dev';

CREATE INDEX IF NOT EXISTS idx_devis_tenant ON quote.devis(tenant_id);
CREATE INDEX IF NOT EXISTS idx_facture_tenant ON quote.facture(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ligne_tenant ON quote.ligne(tenant_id);

ALTER TABLE quote.devis ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON quote.devis;
CREATE POLICY tenant_isolation ON quote.devis
  USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE quote.facture ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON quote.facture;
CREATE POLICY tenant_isolation ON quote.facture
  USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE quote.ligne ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON quote.ligne;
CREATE POLICY tenant_isolation ON quote.ligne
  USING (tenant_id = current_setting('app.tenant_id', true));
