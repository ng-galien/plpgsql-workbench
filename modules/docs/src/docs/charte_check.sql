CREATE OR REPLACE FUNCTION docs.charte_check(p_html text, p_charte_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_violations text[] := ARRAY[]::text[];
  v_style_match text[];
  v_style text;
  v_prop text;
  v_val text;
  v_pair text;
  v_data_id text;
  v_color_props constant text[] := ARRAY['color','background-color','border-color','background','fill','stroke'];
  v_font_props constant text[] := ARRAY['font-family'];
  v_ok_vals constant text[] := ARRAY['transparent','inherit','none','initial','unset','currentColor'];
  r record;
BEGIN
  IF p_charte_id IS NULL THEN RETURN NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM docs.charte WHERE id = p_charte_id) THEN
    RETURN 'Charte not found: ' || p_charte_id;
  END IF;

  -- Extract all style attributes with their data-id context
  FOR r IN
    SELECT m[1] AS data_id, m[2] AS style_val
    FROM regexp_matches(p_html, 'data-id="([^"]*)"[^>]*style="([^"]*)"', 'g') AS m
  LOOP
    FOREACH v_pair IN ARRAY string_to_array(r.style_val, ';')
    LOOP
      v_pair := trim(v_pair);
      IF v_pair = '' THEN CONTINUE; END IF;
      v_prop := lower(trim(split_part(v_pair, ':', 1)));
      v_val := trim(substring(v_pair from position(':' in v_pair) + 1));

      -- Check color properties
      IF v_prop = ANY(v_color_props) THEN
        IF v_val NOT LIKE 'var(--charte-%' AND NOT (lower(v_val) = ANY(v_ok_vals)) THEN
          v_violations := v_violations || format('[%s] %s: %s (should use var(--charte-*))', r.data_id, v_prop, v_val);
        END IF;
      END IF;

      -- Check font properties
      IF v_prop = ANY(v_font_props) THEN
        IF v_val NOT LIKE 'var(--charte-%' AND NOT (lower(v_val) = ANY(v_ok_vals)) THEN
          v_violations := v_violations || format('[%s] %s: %s (should use var(--charte-*))', r.data_id, v_prop, v_val);
        END IF;
      END IF;
    END LOOP;
  END LOOP;

  IF cardinality(v_violations) = 0 THEN
    RETURN NULL;
  END IF;

  RETURN 'Charte violations:' || chr(10) || array_to_string(v_violations, chr(10));
END;
$function$;
