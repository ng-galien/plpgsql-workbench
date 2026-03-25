-- ledger — DDL (comptabilité en partie double)

CREATE SCHEMA IF NOT EXISTS ledger;
CREATE SCHEMA IF NOT EXISTS ledger_ut;
CREATE SCHEMA IF NOT EXISTS ledger_qa;

-- Plan comptable simplifié artisan (PCG)
CREATE TABLE ledger.account (
    id          SERIAL PRIMARY KEY,
    code        TEXT NOT NULL,
    label       TEXT NOT NULL,
    type        TEXT NOT NULL CHECK (type IN ('asset','liability','equity','revenue','expense')),
    parent_code TEXT,
    active      BOOLEAN NOT NULL DEFAULT true,
    tenant_id   TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT account_tenant_code_key UNIQUE (tenant_id, code)
);

-- Écriture comptable (journal entry)
CREATE TABLE ledger.journal_entry (
    id          SERIAL PRIMARY KEY,
    entry_date  DATE NOT NULL DEFAULT CURRENT_DATE,
    reference   TEXT NOT NULL,
    description TEXT NOT NULL,
    posted      BOOLEAN NOT NULL DEFAULT false,
    posted_at   TIMESTAMPTZ,
    invoice_id  INTEGER,
    expense_note_id INTEGER,
    tenant_id   TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fiscal year (close)
CREATE TABLE ledger.fiscal_year (
    id          SERIAL PRIMARY KEY,
    year        INTEGER NOT NULL,
    closed      BOOLEAN NOT NULL DEFAULT false,
    closed_at   TIMESTAMPTZ,
    result      NUMERIC(12,2),
    tenant_id   TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
    CONSTRAINT fiscal_year_tenant_year_key UNIQUE (tenant_id, year)
);
ALTER TABLE ledger.fiscal_year ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON ledger.fiscal_year
    USING (tenant_id = current_setting('app.tenant_id', true));

-- Lignes d'écriture — partie double : SUM(debit) = SUM(credit) par écriture
CREATE TABLE ledger.entry_line (
    id               SERIAL PRIMARY KEY,
    journal_entry_id INTEGER NOT NULL REFERENCES ledger.journal_entry(id) ON DELETE CASCADE,
    account_id       INTEGER NOT NULL REFERENCES ledger.account(id),
    debit            NUMERIC(12,2) NOT NULL DEFAULT 0,
    credit           NUMERIC(12,2) NOT NULL DEFAULT 0,
    label            TEXT NOT NULL DEFAULT '',
    tenant_id        TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
    CONSTRAINT line_debit_or_credit CHECK (debit >= 0 AND credit >= 0 AND (debit > 0 OR credit > 0))
);

-- Indexes
CREATE INDEX idx_account_type ON ledger.account(type);
CREATE INDEX idx_account_tenant ON ledger.account(tenant_id);
CREATE INDEX idx_entry_date ON ledger.journal_entry(entry_date);
CREATE INDEX idx_entry_posted ON ledger.journal_entry(posted);
CREATE INDEX idx_entry_tenant ON ledger.journal_entry(tenant_id);
CREATE UNIQUE INDEX idx_entry_invoice ON ledger.journal_entry(invoice_id) WHERE invoice_id IS NOT NULL;
CREATE UNIQUE INDEX idx_entry_expense_note ON ledger.journal_entry(expense_note_id) WHERE expense_note_id IS NOT NULL;
CREATE INDEX idx_entry_line_entry ON ledger.entry_line(journal_entry_id);
CREATE INDEX idx_entry_line_account ON ledger.entry_line(account_id);
CREATE INDEX idx_entry_line_tenant ON ledger.entry_line(tenant_id);
CREATE INDEX idx_exercice_tenant ON ledger.exercice(tenant_id);

-- RLS
ALTER TABLE ledger.account ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON ledger.account
    USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE ledger.journal_entry ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON ledger.journal_entry
    USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE ledger.entry_line ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON ledger.entry_line
    USING (tenant_id = current_setting('app.tenant_id', true));

