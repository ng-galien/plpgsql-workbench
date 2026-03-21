CREATE OR REPLACE FUNCTION docs.style_merge(p_existing text, p_new text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_props jsonb := '{}'::jsonb;
  v_pair text;
  v_key text;
  v_val text;
  v_result text := '';
  v_k text;
  v_v text;
BEGIN
  -- Parse existing
  IF p_existing IS NOT NULL AND p_existing != '' THEN
    FOREACH v_pair IN ARRAY string_to_array(p_existing, ';')
    LOOP
      v_pair := trim(v_pair);
      IF v_pair = '' THEN CONTINUE; END IF;
      v_key := trim(split_part(v_pair, ':', 1));
      v_val := trim(substring(v_pair from position(':' in v_pair) + 1));
      IF v_key != '' AND v_val != '' THEN
        v_props := v_props || jsonb_build_object(v_key, v_val);
      END IF;
    END LOOP;
  END IF;

  -- Merge new (overwrite)
  IF p_new IS NOT NULL AND p_new != '' THEN
    FOREACH v_pair IN ARRAY string_to_array(p_new, ';')
    LOOP
      v_pair := trim(v_pair);
      IF v_pair = '' THEN CONTINUE; END IF;
      v_key := trim(split_part(v_pair, ':', 1));
      v_val := trim(substring(v_pair from position(':' in v_pair) + 1));
      IF v_key != '' AND v_val != '' THEN
        v_props := v_props || jsonb_build_object(v_key, v_val);
      END IF;
    END LOOP;
  END IF;

  -- Serialize
  FOR v_k, v_v IN SELECT key, value #>> '{}' FROM jsonb_each(v_props)
  LOOP
    IF v_result != '' THEN v_result := v_result || ';'; END IF;
    v_result := v_result || v_k || ':' || v_v;
  END LOOP;

  RETURN v_result;
END;
$function$;
