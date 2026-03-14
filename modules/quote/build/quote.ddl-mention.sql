-- Mentions légales (conditions, pénalités retard, etc.)
CREATE TABLE IF NOT EXISTS quote.mention (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  label text NOT NULL,
  texte text NOT NULL,
  active boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_mention_tenant ON quote.mention(tenant_id);

ALTER TABLE quote.mention ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY tenant_isolation ON quote.mention
    USING (tenant_id = current_setting('app.tenant_id', true));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- GRANT + INSERT moved: GRANT -> pg_pack, INSERT -> quote.seed.sql
