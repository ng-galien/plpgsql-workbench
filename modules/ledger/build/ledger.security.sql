-- ledger — SECURITY DEFINER on all write functions + REVOKE direct writes

-- CRUD write functions
ALTER FUNCTION ledger.journal_entry_create(ledger.journal_entry) SECURITY DEFINER;
ALTER FUNCTION ledger.journal_entry_update(ledger.journal_entry) SECURITY DEFINER;
ALTER FUNCTION ledger.journal_entry_delete(text) SECURITY DEFINER;
ALTER FUNCTION ledger.account_create(ledger.account) SECURITY DEFINER;
ALTER FUNCTION ledger.account_update(ledger.account) SECURITY DEFINER;
ALTER FUNCTION ledger.account_delete(text) SECURITY DEFINER;

-- Legacy post_* write functions
ALTER FUNCTION ledger.post_entry_save(jsonb) SECURITY DEFINER;
ALTER FUNCTION ledger.post_entry_post(jsonb) SECURITY DEFINER;
ALTER FUNCTION ledger.post_entry_delete(jsonb) SECURITY DEFINER;
ALTER FUNCTION ledger.post_line_add(jsonb) SECURITY DEFINER;
ALTER FUNCTION ledger.post_line_delete(jsonb) SECURITY DEFINER;
ALTER FUNCTION ledger.post_cloture(jsonb) SECURITY DEFINER;
ALTER FUNCTION ledger.post_from_facture(jsonb) SECURITY DEFINER;
ALTER FUNCTION ledger.post_from_expense(jsonb) SECURITY DEFINER;

-- REVOKE direct table writes from anon (SELECT stays via pg_pack GRANT)
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ledger FROM anon;
