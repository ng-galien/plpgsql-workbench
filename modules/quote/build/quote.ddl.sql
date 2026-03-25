-- Quote — DDL (Estimates & Invoices)
-- Structure only: tables, indexes, constraints, RLS policies.
-- No GRANT (pg_pack), no CREATE FUNCTION (pg_func_set), no INSERT (quote.seed.sql).

CREATE SCHEMA IF NOT EXISTS quote;
CREATE SCHEMA IF NOT EXISTS quote_ut;
CREATE SCHEMA IF NOT EXISTS quote_qa;

-- Estimates
CREATE TABLE IF NOT EXISTS quote.estimate (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  number text NOT NULL UNIQUE,
  client_id int NOT NULL REFERENCES crm.client(id) ON DELETE CASCADE,
  subject text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'sent', 'accepted', 'declined')),
  notes text NOT NULL DEFAULT '',
  validity_days int NOT NULL DEFAULT 30,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_estimate_client ON quote.estimate(client_id);
CREATE INDEX IF NOT EXISTS idx_estimate_status ON quote.estimate(status);
CREATE INDEX IF NOT EXISTS idx_estimate_tenant ON quote.estimate(tenant_id);

-- Invoices
CREATE TABLE IF NOT EXISTS quote.invoice (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  number text NOT NULL UNIQUE,
  client_id int NOT NULL REFERENCES crm.client(id) ON DELETE CASCADE,
  estimate_id int REFERENCES quote.estimate(id),
  subject text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'sent', 'paid', 'overdue')),
  notes text NOT NULL DEFAULT '',
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invoice_client ON quote.invoice(client_id);
CREATE INDEX IF NOT EXISTS idx_invoice_estimate ON quote.invoice(estimate_id);
CREATE INDEX IF NOT EXISTS idx_invoice_status ON quote.invoice(status);
CREATE INDEX IF NOT EXISTS idx_invoice_tenant ON quote.invoice(tenant_id);

-- Line items (shared between estimates and invoices, XOR constraint)
CREATE TABLE IF NOT EXISTS quote.line_item (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  estimate_id int REFERENCES quote.estimate(id) ON DELETE CASCADE,
  invoice_id int REFERENCES quote.invoice(id) ON DELETE CASCADE,
  sort_order int NOT NULL DEFAULT 0,
  description text NOT NULL,
  quantity numeric(10,2) NOT NULL DEFAULT 1,
  unit text NOT NULL DEFAULT 'u',
  unit_price numeric(12,2) NOT NULL,
  tva_rate numeric(4,2) NOT NULL DEFAULT 20.00
    CHECK (tva_rate IN (0.00, 5.50, 10.00, 20.00)),
  CONSTRAINT line_item_parent_xor
    CHECK ((estimate_id IS NOT NULL AND invoice_id IS NULL)
        OR (estimate_id IS NULL AND invoice_id IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_line_item_estimate ON quote.line_item(estimate_id);
CREATE INDEX IF NOT EXISTS idx_line_item_invoice ON quote.line_item(invoice_id);
CREATE INDEX IF NOT EXISTS idx_line_item_tenant ON quote.line_item(tenant_id);

-- Legal notices
CREATE TABLE IF NOT EXISTS quote.legal_notice (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id', true),
  label text NOT NULL,
  body text NOT NULL,
  active boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_legal_notice_tenant ON quote.legal_notice(tenant_id);

-- RLS
ALTER TABLE quote.estimate ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON quote.estimate
  USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE quote.invoice ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON quote.invoice
  USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE quote.line_item ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON quote.line_item
  USING (tenant_id = current_setting('app.tenant_id', true));

ALTER TABLE quote.legal_notice ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON quote.legal_notice
  USING (tenant_id = current_setting('app.tenant_id', true));
