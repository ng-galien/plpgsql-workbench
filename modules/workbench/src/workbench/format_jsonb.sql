CREATE OR REPLACE FUNCTION workbench.format_jsonb(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_has_nested boolean;
  v_pairs text[] := ARRAY[]::text[];
  v_rec record;
BEGIN
  IF p_data IS NULL THEN RETURN NULL; END IF;
  IF jsonb_typeof(p_data) <> 'object' THEN
    RETURN '<pre><code>' || pgv.esc(jsonb_pretty(p_data)) || '</code></pre>';
  END IF;

  SELECT bool_or(jsonb_typeof(value) IN ('object', 'array'))
    INTO v_has_nested
    FROM jsonb_each(p_data);

  IF coalesce(v_has_nested, false) THEN
    RETURN '<pre><code>' || pgv.esc(jsonb_pretty(p_data)) || '</code></pre>';
  END IF;

  FOR v_rec IN SELECT key, value FROM jsonb_each(p_data)
  LOOP
    v_pairs := v_pairs || pgv.esc(v_rec.key) || CASE
      WHEN jsonb_typeof(v_rec.value) = 'null' THEN '-'
      ELSE pgv.esc(v_rec.value #>> '{}')
    END;
  END LOOP;

  RETURN pgv.dl(VARIADIC v_pairs);
END;
$function$;
