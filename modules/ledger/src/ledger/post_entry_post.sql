CREATE OR REPLACE FUNCTION ledger.post_entry_post(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id integer;
BEGIN
  v_id := (p_data->>'id')::integer;

  IF NOT EXISTS (SELECT 1 FROM ledger.journal_entry WHERE id = v_id AND NOT posted) THEN
    RAISE EXCEPTION 'Écriture introuvable ou déjà validée';
  END IF;

  IF NOT ledger._entry_balanced(v_id) THEN
    RAISE EXCEPTION 'Écriture déséquilibrée : impossible de valider';
  END IF;

  UPDATE ledger.journal_entry SET posted = true WHERE id = v_id;

  RETURN pgv.toast(pgv.t('ledger.toast_entry_posted'))
    || pgv.redirect(pgv.call_ref('get_entry', jsonb_build_object('p_id', v_id)));
END;
$function$;
