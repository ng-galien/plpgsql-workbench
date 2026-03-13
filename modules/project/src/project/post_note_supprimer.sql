CREATE OR REPLACE FUNCTION project.post_note_supprimer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_chantier_id int;
BEGIN
  SELECT n.chantier_id INTO v_chantier_id
    FROM project.note_chantier n
    JOIN project.chantier c ON c.id = n.chantier_id
   WHERE n.id = p_id AND c.statut IN ('preparation','execution');
  IF NOT FOUND THEN
    RAISE EXCEPTION '%', pgv.t('project.err_note_non_modifiable');
  END IF;
  DELETE FROM project.note_chantier WHERE id = p_id;
  RETURN pgv.toast(pgv.t('project.toast_note_supprimee'))
    || pgv.redirect(pgv.call_ref('get_chantier', jsonb_build_object('p_id', v_chantier_id)));
END;
$function$;
