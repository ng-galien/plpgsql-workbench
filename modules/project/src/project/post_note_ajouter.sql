CREATE OR REPLACE FUNCTION project.post_note_ajouter(p_chantier_id integer, p_contenu text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM project.chantier WHERE id = p_chantier_id AND statut IN ('preparation','execution')) THEN
    RAISE EXCEPTION '%', pgv.t('project.err_non_modifiable');
  END IF;
  INSERT INTO project.note_chantier (chantier_id, contenu)
  VALUES (p_chantier_id, p_contenu);
  RETURN pgv.toast(pgv.t('project.toast_note_ajoutee'))
    || pgv.redirect(pgv.call_ref('get_chantier', jsonb_build_object('p_id', p_chantier_id)));
END;
$function$;
