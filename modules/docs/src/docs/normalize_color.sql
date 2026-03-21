CREATE OR REPLACE FUNCTION docs.normalize_color(p_raw text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_raw text;
  v_m text[];
  v_r int; v_g int; v_b int;
BEGIN
  v_raw := lower(trim(p_raw));

  -- #rrggbb
  IF v_raw ~ '^#[0-9a-f]{6}$' THEN
    RETURN v_raw;
  END IF;

  -- #rgb → #rrggbb
  IF v_raw ~ '^#[0-9a-f]{3}$' THEN
    RETURN '#' || substr(v_raw,2,1) || substr(v_raw,2,1)
             || substr(v_raw,3,1) || substr(v_raw,3,1)
             || substr(v_raw,4,1) || substr(v_raw,4,1);
  END IF;

  -- rgb(r, g, b)
  v_m := regexp_match(v_raw, '^rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$');
  IF v_m IS NOT NULL THEN
    v_r := v_m[1]::int;
    v_g := v_m[2]::int;
    v_b := v_m[3]::int;
    IF v_r BETWEEN 0 AND 255 AND v_g BETWEEN 0 AND 255 AND v_b BETWEEN 0 AND 255 THEN
      RETURN '#' || lpad(to_hex(v_r), 2, '0') || lpad(to_hex(v_g), 2, '0') || lpad(to_hex(v_b), 2, '0');
    END IF;
  END IF;

  RETURN NULL;
END;
$function$;
