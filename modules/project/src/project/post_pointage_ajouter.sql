CREATE OR REPLACE FUNCTION project.post_pointage_ajouter(p_chantier_id integer, p_heures numeric, p_description text DEFAULT ''::text, p_date date DEFAULT CURRENT_DATE)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM project.chantier WHERE id = p_chantier_id AND statut IN ('preparation','execution')) THEN
    RAISE EXCEPTION '%', pgv.t('project.err_non_modifiable');
  END IF;
  INSERT INTO project.pointage (chantier_id, date_pointage, heures, description)
  VALUES (p_chantier_id, p_date, p_heures, COALESCE(p_description, ''));
  RETURN pgv.toast(pgv.t('project.toast_pointage_ajoute'))
    || pgv.redirect(pgv.call_ref('get_chantier', jsonb_build_object('p_id', p_chantier_id)));
END;
$function$;
