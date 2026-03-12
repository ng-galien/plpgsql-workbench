CREATE OR REPLACE FUNCTION project.post_affectation_ajouter(p_chantier_id integer, p_nom_intervenant text, p_role text DEFAULT ''::text, p_heures_prevues numeric DEFAULT NULL::numeric)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_statut text;
BEGIN
  SELECT statut INTO v_statut FROM project.chantier WHERE id = p_chantier_id;
  IF v_statut = 'clos' THEN
    RAISE EXCEPTION 'Impossible d''affecter sur un chantier clos';
  END IF;

  INSERT INTO project.affectation (chantier_id, nom_intervenant, role, heures_prevues)
  VALUES (p_chantier_id, trim(p_nom_intervenant), trim(p_role), p_heures_prevues);

  RETURN '<template data-toast="success">Intervenant ajouté</template>'
    || '<template data-redirect="' || pgv.call_ref('get_chantier', jsonb_build_object('p_id', p_chantier_id)) || '"></template>';
END;
$function$;
