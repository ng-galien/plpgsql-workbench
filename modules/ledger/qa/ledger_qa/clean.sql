CREATE OR REPLACE FUNCTION ledger_qa.clean()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
    DELETE FROM ledger.entry_line;
    DELETE FROM ledger.journal_entry;
END;
$function$;
