CREATE OR REPLACE FUNCTION planning.evenement_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_row planning.evenement;
  v_result jsonb;
BEGIN
  SELECT * INTO v_row FROM planning.evenement
  WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RETURN NULL; END IF;

  v_result := to_jsonb(v_row) || jsonb_build_object(
    'chantier_numero', (SELECT ch.numero FROM project.chantier ch WHERE ch.id = v_row.chantier_id),
    'intervenants', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', i.id, 'nom', i.nom, 'role', i.role, 'couleur', i.couleur
      ) ORDER BY i.nom)
      FROM planning.affectation a JOIN planning.intervenant i ON i.id = a.intervenant_id
      WHERE a.evenement_id = v_row.id
    ), '[]'::jsonb)
  );
  RETURN v_result;
END;
$function$;
