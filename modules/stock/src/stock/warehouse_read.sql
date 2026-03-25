CREATE OR REPLACE FUNCTION stock.warehouse_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_data jsonb;
  v_actions jsonb;
  v_active boolean;
BEGIN
  SELECT to_jsonb(w) || jsonb_build_object(
    'article_count', (SELECT count(DISTINCT m.article_id) FROM stock.movement m WHERE m.warehouse_id = w.id)::int
  )
  INTO v_data
  FROM stock.warehouse w
  WHERE w.id = p_id::int AND w.tenant_id = current_setting('app.tenant_id', true);

  IF v_data IS NULL THEN RETURN NULL; END IF;

  v_active := (v_data->>'active')::boolean;
  v_actions := '[]'::jsonb;

  IF v_active THEN
    v_actions := v_actions || jsonb_build_array(
      jsonb_build_object('method', 'deactivate', 'uri', 'stock://warehouse/' || p_id || '/deactivate'),
      jsonb_build_object('method', 'inventory', 'uri', 'stock://warehouse/' || p_id || '/inventory')
    );
  ELSE
    v_actions := v_actions || jsonb_build_array(
      jsonb_build_object('method', 'activate', 'uri', 'stock://warehouse/' || p_id || '/activate')
    );
  END IF;

  v_actions := v_actions || jsonb_build_array(
    jsonb_build_object('method', 'delete', 'uri', 'stock://warehouse/' || p_id || '/delete')
  );

  RETURN v_data || jsonb_build_object('actions', v_actions);
END;
$function$;
