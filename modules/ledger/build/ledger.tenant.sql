-- ledger — Migration multi-tenant : tenant_id + RLS

-- Add tenant_id to all tables
ALTER TABLE ledger.account ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'dev';
ALTER TABLE ledger.journal_entry ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'dev';
ALTER TABLE ledger.entry_line ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'dev';

-- Tenant indexes
CREATE INDEX IF NOT EXISTS idx_account_tenant ON ledger.account(tenant_id);
CREATE INDEX IF NOT EXISTS idx_entry_tenant ON ledger.journal_entry(tenant_id);
CREATE INDEX IF NOT EXISTS idx_entry_line_tenant ON ledger.entry_line(tenant_id);

-- Update UNIQUE constraint on account: (tenant_id, code) instead of (code)
ALTER TABLE ledger.account DROP CONSTRAINT IF EXISTS account_code_key;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'account_tenant_code_key') THEN
        ALTER TABLE ledger.account ADD CONSTRAINT account_tenant_code_key UNIQUE (tenant_id, code);
    END IF;
END $$;

-- RLS
ALTER TABLE ledger.account ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON ledger.account;
CREATE POLICY tenant_isolation ON ledger.account
    USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE ledger.journal_entry ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON ledger.journal_entry;
CREATE POLICY tenant_isolation ON ledger.journal_entry
    USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE ledger.entry_line ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON ledger.entry_line;
CREATE POLICY tenant_isolation ON ledger.entry_line
    USING (tenant_id = current_setting('app.tenant_id', true));
