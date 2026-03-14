-- ledger — Migration: facture_id FK + exercice table

-- Add facture_id to journal_entry (one facture = one entry max)
ALTER TABLE ledger.journal_entry ADD COLUMN IF NOT EXISTS facture_id INTEGER;
CREATE UNIQUE INDEX IF NOT EXISTS idx_entry_facture ON ledger.journal_entry(facture_id) WHERE facture_id IS NOT NULL;

-- Exercice comptable (clôture)
CREATE TABLE IF NOT EXISTS ledger.exercice (
    id          SERIAL PRIMARY KEY,
    year        INTEGER NOT NULL,
    closed      BOOLEAN NOT NULL DEFAULT false,
    closed_at   TIMESTAMPTZ,
    result      NUMERIC(12,2),
    tenant_id   TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
    CONSTRAINT exercice_tenant_year_key UNIQUE (tenant_id, year)
);
CREATE INDEX IF NOT EXISTS idx_exercice_tenant ON ledger.exercice(tenant_id);

ALTER TABLE ledger.exercice ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON ledger.exercice;
CREATE POLICY tenant_isolation ON ledger.exercice
    USING (tenant_id = current_setting('app.tenant_id', true));

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON ledger.exercice TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ledger TO anon;
