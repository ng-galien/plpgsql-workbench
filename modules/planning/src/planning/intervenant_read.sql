CREATE OR REPLACE FUNCTION planning.intervenant_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_row planning.intervenant;
  v_result jsonb;
BEGIN
  SELECT * INTO v_row FROM planning.intervenant
  WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RETURN NULL; END IF;

  v_result := to_jsonb(v_row) || jsonb_build_object(
    'nb_evt_actifs', (SELECT count(*)::int FROM planning.affectation a
                      JOIN planning.evenement e ON e.id = a.evenement_id
                      WHERE a.intervenant_id = v_row.id AND e.date_fin >= current_date),
    'evenements', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', e.id, 'titre', e.titre, 'type', e.type,
        'date_debut', e.date_debut, 'date_fin', e.date_fin, 'lieu', e.lieu
      ) ORDER BY e.date_debut)
      FROM planning.evenement e
      JOIN planning.affectation a ON a.evenement_id = e.id
      WHERE a.intervenant_id = v_row.id AND e.date_fin >= current_date
    ), '[]'::jsonb)
  );

  -- HATEOAS actions based on state
  IF v_row.actif THEN
    v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
      jsonb_build_object('method', 'deactivate', 'uri', 'planning://intervenant/' || p_id || '/deactivate'),
      jsonb_build_object('method', 'delete', 'uri', 'planning://intervenant/' || p_id)
    ));
  ELSE
    v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
      jsonb_build_object('method', 'activate', 'uri', 'planning://intervenant/' || p_id || '/activate'),
      jsonb_build_object('method', 'delete', 'uri', 'planning://intervenant/' || p_id)
    ));
  END IF;

  RETURN v_result;
END;
$function$;
