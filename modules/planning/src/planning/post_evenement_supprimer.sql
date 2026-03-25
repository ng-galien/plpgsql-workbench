CREATE OR REPLACE FUNCTION planning.post_evenement_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  DELETE FROM planning.evenement WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('planning.err_evenement_not_found'), 'error');
  END IF;
  RETURN pgv.toast(pgv.t('planning.toast_evenement_deleted'))
      || pgv.redirect(pgv.call_ref('get_evenements'));
END;
$function$;
