CREATE OR REPLACE FUNCTION sdui._parse_uri(p_uri text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_uri text := p_uri;
  v_schema text;
  v_entity text;
  v_id text;
  v_method text;
  v_filter text;
  v_fragment text;
  v_path text;
  v_parts text[];
BEGIN
  -- Extract fragment (#schema)
  IF v_uri LIKE '%#%' THEN
    v_fragment := split_part(v_uri, '#', 2);
    v_uri := split_part(v_uri, '#', 1);
  END IF;

  -- Extract query params (?filter=...)
  IF v_uri LIKE '%?%' THEN
    FOR v_path IN
      SELECT pair FROM unnest(string_to_array(split_part(v_uri, '?', 2), '&')) AS pair
    LOOP
      IF v_path LIKE 'filter=%' THEN
        v_filter := substr(v_path, 8);
      END IF;
    END LOOP;
    v_uri := split_part(v_uri, '?', 1);
  END IF;

  -- Parse schema://path
  IF v_uri LIKE '%://%' THEN
    v_schema := split_part(v_uri, '://', 1);
    v_path := split_part(v_uri, '://', 2);
  ELSE
    v_path := v_uri;
  END IF;

  -- Handle empty schema (catalog)
  IF v_schema = '' THEN v_schema := NULL; END IF;

  -- Parse path: entity/id/method
  IF v_path IS NOT NULL AND v_path != '' THEN
    v_parts := string_to_array(v_path, '/');
    v_entity := v_parts[1];
    IF v_entity = '' THEN v_entity := NULL; END IF;
    IF array_length(v_parts, 1) >= 2 AND v_parts[2] != '' THEN
      v_id := v_parts[2];
    END IF;
    IF array_length(v_parts, 1) >= 3 AND v_parts[3] != '' THEN
      v_method := v_parts[3];
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'schema', v_schema,
    'entity', v_entity,
    'id', v_id,
    'method', v_method,
    'filter', v_filter,
    'fragment', v_fragment
  );
END;
$function$;
