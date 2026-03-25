-- ledger — Language rename: French → English

-- Table rename
ALTER TABLE IF EXISTS ledger.exercice RENAME TO fiscal_year;

-- Column rename
ALTER TABLE ledger.journal_entry RENAME COLUMN facture_id TO invoice_id;

-- Index renames (follow table/column)
ALTER INDEX IF EXISTS ledger.exercice_tenant_year_key RENAME TO fiscal_year_tenant_year_key;
ALTER INDEX IF EXISTS ledger.idx_exercice_tenant RENAME TO idx_fiscal_year_tenant;
ALTER INDEX IF EXISTS ledger.idx_entry_facture RENAME TO idx_entry_invoice;

