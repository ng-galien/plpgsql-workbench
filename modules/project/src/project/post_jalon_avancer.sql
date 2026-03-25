CREATE OR REPLACE FUNCTION project.post_jalon_avancer(p_id integer, p_pct numeric)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_chantier_id int;
BEGIN
  SELECT j.chantier_id INTO v_chantier_id
    FROM project.jalon j
    JOIN project.chantier c ON c.id = j.chantier_id
   WHERE j.id = p_id AND c.statut IN ('preparation','execution');
  IF NOT FOUND THEN
    RAISE EXCEPTION '%', pgv.t('project.err_jalon_non_modifiable');
  END IF;
  UPDATE project.jalon SET
    pct_avancement = LEAST(GREATEST(p_pct, 0), 100),
    statut = CASE WHEN p_pct >= 100 THEN 'valide' WHEN p_pct > 0 THEN 'en_cours' ELSE 'a_faire' END
  WHERE id = p_id;
  RETURN pgv.toast(pgv.t('project.toast_avancement_maj'))
    || pgv.redirect(pgv.call_ref('get_chantier', jsonb_build_object('p_id', v_chantier_id)));
END;
$function$;
