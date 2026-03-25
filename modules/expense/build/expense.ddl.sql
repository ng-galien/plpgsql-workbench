-- expense — DDL

CREATE SCHEMA IF NOT EXISTS expense;
CREATE SCHEMA IF NOT EXISTS expense_ut;
CREATE SCHEMA IF NOT EXISTS expense_qa;

-- Expense categories
CREATE TABLE IF NOT EXISTS expense.category (
  id serial PRIMARY KEY,
  name text NOT NULL,
  accounting_code text,
  created_at timestamptz DEFAULT now()
);

-- Expense reports (grouping)
CREATE TABLE IF NOT EXISTS expense.expense_report (
  id serial PRIMARY KEY,
  reference text UNIQUE,
  author text NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'validated', 'reimbursed', 'rejected')),
  comment text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Expense lines
CREATE TABLE IF NOT EXISTS expense.line (
  id serial PRIMARY KEY,
  note_id integer NOT NULL REFERENCES expense.expense_report(id) ON DELETE CASCADE,
  expense_date date NOT NULL,
  category_id integer REFERENCES expense.category(id),
  description text NOT NULL,
  amount_excl_tax numeric(12,2) NOT NULL,
  vat numeric(12,2) DEFAULT 0,
  amount_incl_tax numeric(12,2) GENERATED ALWAYS AS (amount_excl_tax + vat) STORED,
  receipt text,
  km numeric(8,1),
  created_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_report_status ON expense.expense_report(status);
CREATE INDEX IF NOT EXISTS idx_report_author ON expense.expense_report(author);
CREATE INDEX IF NOT EXISTS idx_line_note ON expense.line(note_id);
CREATE INDEX IF NOT EXISTS idx_line_date ON expense.line(expense_date);

-- Grants: SELECT only (writes via SECURITY DEFINER functions)
GRANT USAGE ON SCHEMA expense TO anon;
GRANT SELECT ON ALL TABLES IN SCHEMA expense TO anon;
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA expense FROM anon;
GRANT USAGE ON SCHEMA expense_ut TO anon;
GRANT USAGE ON SCHEMA expense_qa TO anon;
