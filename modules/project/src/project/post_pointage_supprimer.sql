CREATE OR REPLACE FUNCTION project.post_pointage_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_chantier_id int;
BEGIN
  SELECT p.chantier_id INTO v_chantier_id
    FROM project.pointage p
    JOIN project.chantier c ON c.id = p.chantier_id
   WHERE p.id = p_id AND c.statut IN ('preparation','execution');
  IF NOT FOUND THEN
    RAISE EXCEPTION '%', pgv.t('project.err_pointage_non_modifiable');
  END IF;
  DELETE FROM project.pointage WHERE id = p_id;
  RETURN pgv.toast(pgv.t('project.toast_pointage_supprime'))
    || pgv.redirect(pgv.call_ref('get_chantier', jsonb_build_object('p_id', v_chantier_id)));
END;
$function$;
