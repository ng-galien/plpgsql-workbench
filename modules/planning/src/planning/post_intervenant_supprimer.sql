CREATE OR REPLACE FUNCTION planning.post_intervenant_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM planning.intervenant WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('planning.err_intervenant_not_found'), 'error');
  END IF;
  RETURN pgv.toast(pgv.t('planning.toast_intervenant_deleted'))
      || pgv.redirect(pgv.call_ref('get_intervenants'));
END;
$function$;
