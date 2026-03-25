CREATE OR REPLACE FUNCTION asset.asset_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT to_jsonb(a) INTO v_result
  FROM asset.asset a
  WHERE a.id::text = p_id AND a.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;

  -- HATEOAS actions based on status
  CASE v_result->>'status'
    WHEN 'to_classify' THEN
      v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
        jsonb_build_object('method', 'classify', 'uri', 'asset://asset/' || p_id || '/classify'),
        jsonb_build_object('method', 'delete', 'uri', 'asset://asset/' || p_id)
      ));
    WHEN 'classified' THEN
      v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
        jsonb_build_object('method', 'edit', 'uri', 'asset://asset/' || p_id),
        jsonb_build_object('method', 'archive', 'uri', 'asset://asset/' || p_id || '/archive'),
        jsonb_build_object('method', 'delete', 'uri', 'asset://asset/' || p_id)
      ));
    WHEN 'archived' THEN
      v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
        jsonb_build_object('method', 'restore', 'uri', 'asset://asset/' || p_id || '/restore'),
        jsonb_build_object('method', 'delete', 'uri', 'asset://asset/' || p_id)
      ));
  END CASE;

  RETURN v_result;
END;
$function$;
