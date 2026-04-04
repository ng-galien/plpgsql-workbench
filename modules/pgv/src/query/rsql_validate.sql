CREATE OR REPLACE FUNCTION pgv.rsql_validate(p_filter text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_filter text;
  v_parts text[];
  v_part text;
  v_atoms text[];
  v_atom text;
BEGIN
  IF p_filter IS NULL OR trim(p_filter) = '' THEN
    RETURN true;
  END IF;

  -- Protect commas inside parentheses
  v_filter := p_filter;
  WHILE v_filter ~ '\([^)]*,[^)]*\)' LOOP
    v_filter := regexp_replace(v_filter, '\(([^)]*),([^)]*)\)', '(\1' || chr(1) || '\2)', 'g');
  END LOOP;

  -- Split by , (OR)
  v_parts := string_to_array(v_filter, ',');

  FOREACH v_part IN ARRAY v_parts LOOP
    -- Split by ; (AND)
    v_atoms := string_to_array(v_part, ';');
    FOREACH v_atom IN ARRAY v_atoms LOOP
      IF NOT v_atom ~ '^[a-zA-Z_][a-zA-Z0-9_]*(==|!=|>=|<=|>|<|=in=|=out=|=like=|=ilike=|=isnull=|=notnull=|=bt=).+$' THEN
        RETURN false;
      END IF;
    END LOOP;
  END LOOP;

  RETURN true;
END;
$function$;
