CREATE OR REPLACE FUNCTION project.post_chantier_clore(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE project.chantier
     SET statut = 'clos',
         date_fin_reelle = COALESCE(date_fin_reelle, CURRENT_DATE),
         updated_at = now()
   WHERE id = p_id AND statut = 'reception';
  IF NOT FOUND THEN
    RAISE EXCEPTION '%', pgv.t('project.err_pas_reception');
  END IF;
  RETURN pgv.toast(pgv.t('project.toast_clos'))
    || pgv.redirect(pgv.call_ref('get_chantier', jsonb_build_object('p_id', p_id)));
END;
$function$;
