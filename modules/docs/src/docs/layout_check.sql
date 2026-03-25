CREATE OR REPLACE FUNCTION docs.layout_check(p_html text, p_width numeric, p_height numeric)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_overflows text[] := ARRAY[]::text[];
  v_w_match text[];
  v_h_match text[];
  v_w numeric;
  v_h numeric;
  r record;
BEGIN
  FOR r IN
    SELECT m[1] AS data_id, m[2] AS style_val
    FROM regexp_matches(p_html, 'data-id="([^"]*)"[^>]*style="([^"]*)"', 'g') AS m
  LOOP
    -- Extract width
    v_w_match := regexp_match(r.style_val, 'width:\s*([0-9.]+)\s*mm');
    v_w := CASE WHEN v_w_match IS NOT NULL THEN v_w_match[1]::numeric ELSE NULL END;

    -- Extract height
    v_h_match := regexp_match(r.style_val, 'height:\s*([0-9.]+)\s*mm');
    v_h := CASE WHEN v_h_match IS NOT NULL THEN v_h_match[1]::numeric ELSE NULL END;

    IF v_w IS NOT NULL AND v_w > p_width THEN
      v_overflows := v_overflows || format('[%s] width %smm > canvas %smm', r.data_id, v_w, p_width);
    END IF;
    IF v_h IS NOT NULL AND v_h > p_height THEN
      v_overflows := v_overflows || format('[%s] height %smm > canvas %smm', r.data_id, v_h, p_height);
    END IF;
  END LOOP;

  IF cardinality(v_overflows) = 0 THEN
    RETURN NULL;
  END IF;

  RETURN 'Layout overflows:' || chr(10) || array_to_string(v_overflows, chr(10));
END;
$function$;
