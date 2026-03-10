CREATE OR REPLACE FUNCTION pgv.md_table(p_headers text[], p_rows text[])
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_md text;
  v_sep text;
  i int;
BEGIN
  v_md := '| ' || array_to_string(p_headers, ' | ') || E' |\n';
  v_sep := '|';
  FOR i IN 1..array_length(p_headers, 1) LOOP
    v_sep := v_sep || ' --- |';
  END LOOP;
  v_md := v_md || v_sep || E'\n';
  IF p_rows IS NOT NULL AND array_length(p_rows, 1) > 0 THEN
    FOR i IN 1..array_length(p_rows, 1) LOOP
      v_md := v_md || '| ' || array_to_string(p_rows[i:i][1:array_length(p_headers, 1)], ' | ') || E' |\n';
    END LOOP;
  END IF;
  RETURN '<figure><md>' || v_md || '</md></figure>';
END;
$function$;
