-- Migration 002: expense integration — add expense_note_id + account 421

ALTER TABLE ledger.journal_entry ADD COLUMN IF NOT EXISTS expense_note_id INTEGER;

CREATE UNIQUE INDEX IF NOT EXISTS idx_entry_expense_note
  ON ledger.journal_entry(expense_note_id) WHERE expense_note_id IS NOT NULL;

INSERT INTO ledger.account (code, label, type) VALUES
  ('421', 'Personnel — rémunérations dues', 'liability')
ON CONFLICT DO NOTHING;
