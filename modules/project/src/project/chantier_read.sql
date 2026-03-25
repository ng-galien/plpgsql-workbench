CREATE OR REPLACE FUNCTION project.chantier_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_row jsonb;
  v_statut text;
  v_actions jsonb := '[]'::jsonb;
  v_uri text;
BEGIN
  SELECT to_jsonb(c) || jsonb_build_object(
    'client_name', cl.name,
    'devis_numero', d.numero,
    'avancement', project._avancement_global(c.id),
    'heures_total', (SELECT COALESCE(sum(heures), 0) FROM project.pointage WHERE chantier_id = c.id),
    'jalons_count', (SELECT count(*) FROM project.jalon WHERE chantier_id = c.id)
  ) INTO v_row
  FROM project.chantier c
  JOIN crm.client cl ON cl.id = c.client_id
  LEFT JOIN quote.devis d ON d.id = c.devis_id
  WHERE c.id = p_id::int AND c.tenant_id = current_setting('app.tenant_id', true);

  IF v_row IS NULL THEN RETURN NULL; END IF;

  v_statut := v_row ->> 'statut';
  v_uri := 'project://chantier/' || p_id;

  CASE v_statut
    WHEN 'preparation' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'demarrer', 'uri', v_uri || '/demarrer'),
        jsonb_build_object('method', 'edit', 'uri', v_uri),
        jsonb_build_object('method', 'supprimer', 'uri', v_uri || '/supprimer')
      );
    WHEN 'execution' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'reception', 'uri', v_uri || '/reception'),
        jsonb_build_object('method', 'edit', 'uri', v_uri)
      );
    WHEN 'reception' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'clore', 'uri', v_uri || '/clore')
      );
    ELSE
      v_actions := '[]'::jsonb;
  END CASE;

  v_row := v_row || jsonb_build_object('actions', v_actions);
  RETURN v_row;
END;
$function$;
