CREATE OR REPLACE FUNCTION project.post_jalon_valider(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_chantier_id int;
  v_sort int;
  v_prev_not_valide boolean;
BEGIN
  SELECT j.chantier_id, j.sort_order INTO v_chantier_id, v_sort
    FROM project.jalon j
    JOIN project.chantier c ON c.id = j.chantier_id
   WHERE j.id = p_id AND j.statut <> 'valide' AND c.statut IN ('preparation','execution');
  IF NOT FOUND THEN
    RAISE EXCEPTION '%', pgv.t('project.err_jalon_deja_valide');
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM project.jalon
     WHERE chantier_id = v_chantier_id AND sort_order < v_sort AND statut <> 'valide'
  ) INTO v_prev_not_valide;

  IF v_prev_not_valide THEN
    RAISE EXCEPTION '%', pgv.t('project.err_jalons_precedents');
  END IF;

  UPDATE project.jalon SET
    statut = 'valide',
    pct_avancement = 100,
    date_reelle = CURRENT_DATE
  WHERE id = p_id;

  RETURN pgv.toast(pgv.t('project.toast_jalon_valide'))
    || pgv.redirect(pgv.call_ref('get_chantier', jsonb_build_object('p_id', v_chantier_id)));
END;
$function$;
