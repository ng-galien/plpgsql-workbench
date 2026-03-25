CREATE OR REPLACE FUNCTION docs.charter_check(p_html text, p_charter_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_violations text[] := ARRAY[]::text[];
  v_prop text; v_val text; v_pair text;
  v_color_props constant text[] := ARRAY['color','background-color','border-color','background','fill','stroke'];
  v_font_props constant text[] := ARRAY['font-family'];
  v_ok_vals constant text[] := ARRAY['transparent','inherit','none','initial','unset','currentColor'];
  r record;
BEGIN
  IF p_charter_id IS NULL THEN RETURN NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM docs.charter WHERE id = p_charter_id) THEN
    RETURN 'Charter not found: ' || p_charter_id;
  END IF;
  FOR r IN SELECT m[1] AS data_id, m[2] AS style_val FROM regexp_matches(p_html, 'data-id="([^"]*)"[^>]*style="([^"]*)"', 'g') AS m
  LOOP
    FOREACH v_pair IN ARRAY string_to_array(r.style_val, ';') LOOP
      v_pair := trim(v_pair); IF v_pair = '' THEN CONTINUE; END IF;
      v_prop := lower(trim(split_part(v_pair, ':', 1)));
      v_val := trim(substring(v_pair from position(':' in v_pair) + 1));
      IF v_prop = ANY(v_color_props) AND v_val NOT LIKE 'var(--charte-%' AND NOT (lower(v_val) = ANY(v_ok_vals)) THEN
        v_violations := v_violations || format('[%s] %s: %s (should use var(--charte-*))', r.data_id, v_prop, v_val);
      END IF;
      IF v_prop = ANY(v_font_props) AND v_val NOT LIKE 'var(--charte-%' AND NOT (lower(v_val) = ANY(v_ok_vals)) THEN
        v_violations := v_violations || format('[%s] %s: %s (should use var(--charte-*))', r.data_id, v_prop, v_val);
      END IF;
    END LOOP;
  END LOOP;
  IF cardinality(v_violations) = 0 THEN RETURN NULL; END IF;
  RETURN 'Charter violations:' || chr(10) || array_to_string(v_violations, chr(10));
END;
$function$;
