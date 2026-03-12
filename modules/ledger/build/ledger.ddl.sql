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
    facture_id  INTEGER,
    expense_note_id INTEGER,
    tenant_id   TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Exercice comptable (clôture)
CREATE TABLE ledger.exercice (
    id          SERIAL PRIMARY KEY,
    year        INTEGER NOT NULL,
    closed      BOOLEAN NOT NULL DEFAULT false,
    closed_at   TIMESTAMPTZ,
    result      NUMERIC(12,2),
    tenant_id   TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
    CONSTRAINT exercice_tenant_year_key UNIQUE (tenant_id, year)
);
ALTER TABLE ledger.exercice ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON ledger.exercice
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
CREATE UNIQUE INDEX idx_entry_facture ON ledger.journal_entry(facture_id) WHERE facture_id IS NOT NULL;
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

-- Trigger : écriture validée = immutable
CREATE OR REPLACE FUNCTION ledger._protect_posted()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.posted THEN
            RAISE EXCEPTION 'Écriture validée : suppression interdite (id=%)', OLD.id;
        END IF;
        RETURN OLD;
    END IF;
    IF OLD.posted AND NEW.posted THEN
        RAISE EXCEPTION 'Écriture validée : modification interdite (id=%)', OLD.id;
    END IF;
    IF NEW.posted AND NOT OLD.posted THEN
        NEW.posted_at := now();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_posted
    BEFORE UPDATE OR DELETE ON ledger.journal_entry
    FOR EACH ROW EXECUTE FUNCTION ledger._protect_posted();

-- Trigger : lignes d'une écriture validée = immutables
CREATE OR REPLACE FUNCTION ledger._protect_posted_lines()
RETURNS TRIGGER AS $$
DECLARE
    v_posted BOOLEAN;
BEGIN
    IF TG_OP = 'DELETE' THEN
        SELECT posted INTO v_posted FROM ledger.journal_entry WHERE id = OLD.journal_entry_id;
    ELSE
        SELECT posted INTO v_posted FROM ledger.journal_entry WHERE id = NEW.journal_entry_id;
    END IF;
    IF v_posted THEN
        RAISE EXCEPTION 'Écriture validée : modification des lignes interdite';
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_posted_lines
    BEFORE INSERT OR UPDATE OR DELETE ON ledger.entry_line
    FOR EACH ROW EXECUTE FUNCTION ledger._protect_posted_lines();

-- Plan comptable simplifié artisan (PCG)
INSERT INTO ledger.account (code, label, type) VALUES
    -- Capitaux
    ('108',  'Compte de l''exploitant',     'equity'),
    ('120',  'Résultat de l''exercice',      'equity'),
    -- Actifs
    ('2154', 'Outillage industriel',         'asset'),
    ('2182', 'Matériel de transport',        'asset'),
    ('411',  'Clients',                      'asset'),
    ('4456', 'TVA déductible',               'asset'),
    ('512',  'Banque',                       'asset'),
    ('530',  'Caisse',                       'asset'),
    -- Passifs
    ('401',  'Fournisseurs',                 'liability'),
    ('421',  'Personnel — rémunérations dues', 'liability'),
    ('4457', 'TVA collectée',                'liability'),
    -- Charges (PCG classe 6)
    ('601',  'Achats matériaux',             'expense'),
    ('602',  'Achats fournitures',           'expense'),
    ('604',  'Sous-traitance',               'expense'),
    ('606',  'Assurances',                   'expense'),
    ('613',  'Loyer',                        'expense'),
    ('616',  'Télécom',                      'expense'),
    ('625',  'Déplacements',                 'expense'),
    ('626',  'Frais postaux',                'expense'),
    ('627',  'Services bancaires',           'expense'),
    ('6354', 'Taxe véhicule',               'expense'),
    ('6411', 'Salaires',                     'expense'),
    -- Produits (PCG classe 7)
    ('706',  'Prestations de services',      'revenue'),
    ('707',  'Ventes de marchandises',       'revenue')
ON CONFLICT DO NOTHING;

-- Grants
GRANT USAGE ON SCHEMA ledger TO web_anon;
GRANT USAGE ON SCHEMA ledger_ut TO web_anon;
GRANT USAGE ON SCHEMA ledger_qa TO web_anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ledger TO web_anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ledger TO web_anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ledger TO web_anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ledger_ut TO web_anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ledger_qa TO web_anon;
