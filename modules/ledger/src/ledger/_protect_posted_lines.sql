CREATE OR REPLACE FUNCTION ledger._protect_posted_lines()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$;
