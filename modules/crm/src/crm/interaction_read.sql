CREATE OR REPLACE FUNCTION crm.interaction_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT to_jsonb(i) || jsonb_build_object('client_name', c.name)
  INTO v_result
  FROM crm.interaction i
  JOIN crm.client c ON c.id = i.client_id
  WHERE i.id::text = p_id AND i.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;

  -- HATEOAS actions (interactions are append-only, only delete available)
  v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
    jsonb_build_object('method', 'delete', 'uri', 'crm://interaction/' || p_id)
  ));

  RETURN v_result;
END;
$function$;
