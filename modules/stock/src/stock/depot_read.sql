CREATE OR REPLACE FUNCTION stock.depot_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_data jsonb;
  v_actions jsonb;
  v_actif boolean;
BEGIN
  SELECT to_jsonb(d) || jsonb_build_object(
    'nb_articles', (SELECT count(DISTINCT m.article_id) FROM stock.mouvement m WHERE m.depot_id = d.id)::int
  )
  INTO v_data
  FROM stock.depot d
  WHERE d.id = p_id::int AND d.tenant_id = current_setting('app.tenant_id', true);

  IF v_data IS NULL THEN RETURN NULL; END IF;

  v_actif := (v_data->>'actif')::boolean;
  v_actions := '[]'::jsonb;

  IF v_actif THEN
    v_actions := v_actions || jsonb_build_array(
      jsonb_build_object('method', 'deactivate', 'uri', 'stock://depot/' || p_id || '/deactivate'),
      jsonb_build_object('method', 'inventory', 'uri', 'stock://depot/' || p_id || '/inventory')
    );
  ELSE
    v_actions := v_actions || jsonb_build_array(
      jsonb_build_object('method', 'activate', 'uri', 'stock://depot/' || p_id || '/activate')
    );
  END IF;

  v_actions := v_actions || jsonb_build_array(
    jsonb_build_object('method', 'delete', 'uri', 'stock://depot/' || p_id || '/delete')
  );

  RETURN v_data || jsonb_build_object('actions', v_actions);
END;
$function$;
