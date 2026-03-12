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
    RAISE EXCEPTION 'Jalon introuvable, déjà validé, ou chantier non modifiable';
  END IF;

  -- Vérifier que tous les jalons précédents sont validés
  SELECT EXISTS (
    SELECT 1 FROM project.jalon
     WHERE chantier_id = v_chantier_id AND sort_order < v_sort AND statut <> 'valide'
  ) INTO v_prev_not_valide;

  IF v_prev_not_valide THEN
    RAISE EXCEPTION 'Les jalons précédents doivent être validés avant';
  END IF;

  UPDATE project.jalon SET
    statut = 'valide',
    pct_avancement = 100,
    date_reelle = CURRENT_DATE
  WHERE id = p_id;

  RETURN '<template data-toast="success">Jalon validé</template>'
    || '<template data-redirect="' || pgv.call_ref('get_chantier', jsonb_build_object('p_id', v_chantier_id)) || '"></template>';
END;
$function$;
