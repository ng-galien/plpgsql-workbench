CREATE OR REPLACE FUNCTION project.post_chantier_reception(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE project.chantier
     SET statut = 'reception', updated_at = now()
   WHERE id = p_id AND statut = 'execution';
  IF NOT FOUND THEN
    RAISE EXCEPTION '%', pgv.t('project.err_pas_en_cours');
  END IF;
  RETURN pgv.toast(pgv.t('project.toast_reception'))
    || pgv.redirect(pgv.call_ref('get_chantier', jsonb_build_object('p_id', p_id)));
END;
$function$;
