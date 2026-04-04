-- Add GENERATED column that PLX entity-ddl does not support yet
ALTER TABLE expense.line
  ADD COLUMN IF NOT EXISTS amount_incl_tax numeric(12,2)
  GENERATED ALWAYS AS (amount_excl_tax + vat) STORED;

-- Additional indexes
CREATE INDEX IF NOT EXISTS idx_line_date ON expense.line(expense_date);
CREATE INDEX IF NOT EXISTS idx_report_status ON expense.expense_report(status);
CREATE INDEX IF NOT EXISTS idx_report_author ON expense.expense_report(author);
