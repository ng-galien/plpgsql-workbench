CREATE OR REPLACE FUNCTION project.post_affectation_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_chantier_id int;
  v_statut text;
BEGIN
  SELECT a.chantier_id, c.statut INTO v_chantier_id, v_statut
    FROM project.affectation a
    JOIN project.chantier c ON c.id = a.chantier_id
   WHERE a.id = p_id;

  IF v_statut = 'clos' THEN
    RAISE EXCEPTION '%', pgv.t('project.err_projet_clos_modification');
  END IF;

  DELETE FROM project.affectation WHERE id = p_id;

  RETURN pgv.toast(pgv.t('project.toast_affectation_supprimee'))
    || pgv.redirect(pgv.call_ref('get_chantier', jsonb_build_object('p_id', v_chantier_id)));
END;
$function$;
