CREATE OR REPLACE FUNCTION ledger._protect_posted()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$;
