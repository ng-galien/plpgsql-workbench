CREATE OR REPLACE FUNCTION crm.client_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT to_jsonb(c) || jsonb_build_object(
    'contacts', COALESCE((SELECT jsonb_agg(to_jsonb(ct) ORDER BY ct.is_primary DESC, ct.name) FROM crm.contact ct WHERE ct.client_id = c.id), '[]'::jsonb),
    'interaction_count', (SELECT count(*) FROM crm.interaction i WHERE i.client_id = c.id)
  ) INTO v_result
  FROM crm.client c
  WHERE c.id::text = p_id AND c.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;

  -- HATEOAS actions based on state
  IF (v_result->>'active')::boolean THEN
    v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
      jsonb_build_object('method', 'archive', 'uri', 'crm://client/' || p_id || '/archive'),
      jsonb_build_object('method', 'delete', 'uri', 'crm://client/' || p_id)
    ));
  ELSE
    v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
      jsonb_build_object('method', 'activate', 'uri', 'crm://client/' || p_id || '/activate'),
      jsonb_build_object('method', 'delete', 'uri', 'crm://client/' || p_id)
    ));
  END IF;

  RETURN v_result;
END;
$function$;
