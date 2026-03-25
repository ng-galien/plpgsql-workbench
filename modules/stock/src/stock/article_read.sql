CREATE OR REPLACE FUNCTION stock.article_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_data jsonb;
  v_actions jsonb;
  v_active boolean;
BEGIN
  SELECT to_jsonb(a) || jsonb_build_object(
    'supplier_name', c.name,
    'current_stock', stock._current_stock(a.id)
  )
  INTO v_data
  FROM stock.article a
  LEFT JOIN crm.client c ON c.id = a.supplier_id
  WHERE a.id = p_id::int AND a.tenant_id = current_setting('app.tenant_id', true);

  IF v_data IS NULL THEN RETURN NULL; END IF;

  v_active := (v_data->>'active')::boolean;
  v_actions := '[]'::jsonb;

  IF v_active THEN
    v_actions := v_actions || jsonb_build_array(
      jsonb_build_object('method', 'deactivate', 'uri', 'stock://article/' || p_id || '/deactivate')
    );
  ELSE
    v_actions := v_actions || jsonb_build_array(
      jsonb_build_object('method', 'activate', 'uri', 'stock://article/' || p_id || '/activate')
    );
  END IF;

  v_actions := v_actions || jsonb_build_array(
    jsonb_build_object('method', 'delete', 'uri', 'stock://article/' || p_id || '/delete')
  );

  RETURN v_data || jsonb_build_object('actions', v_actions);
END;
$function$;
