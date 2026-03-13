CREATE OR REPLACE FUNCTION ledger.post_entry_delete(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id integer;
BEGIN
  v_id := (p_data->>'id')::integer;

  IF NOT EXISTS (SELECT 1 FROM ledger.journal_entry WHERE id = v_id AND NOT posted) THEN
    RAISE EXCEPTION 'Écriture introuvable ou déjà validée — suppression impossible';
  END IF;

  DELETE FROM ledger.journal_entry WHERE id = v_id;

  RETURN pgv.toast(pgv.t('ledger.toast_entry_deleted'))
    || pgv.redirect(pgv.call_ref('get_entries'));
END;
$function$;
