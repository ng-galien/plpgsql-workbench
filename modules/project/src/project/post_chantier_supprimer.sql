CREATE OR REPLACE FUNCTION project.post_chantier_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM project.chantier WHERE id = p_id AND statut = 'preparation') THEN
    RAISE EXCEPTION '%', pgv.t('project.err_seuls_supprimables');
  END IF;
  DELETE FROM project.chantier WHERE id = p_id;
  RETURN pgv.toast(pgv.t('project.toast_supprime'))
    || pgv.redirect(pgv.call_ref('get_chantiers'));
END;
$function$;
