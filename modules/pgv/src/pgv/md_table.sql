CREATE OR REPLACE FUNCTION pgv.md_table(p_headers text[], p_rows text[], p_page_size integer DEFAULT 0)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_md text;
  v_sep text;
  v_ncols int;
  v_nrows int;
BEGIN
  v_ncols := array_length(p_headers, 1);
  IF p_rows IS NOT NULL AND array_length(p_rows, 1) % v_ncols <> 0 THEN
    RAISE EXCEPTION 'md_table: p_rows length % is not a multiple of % columns',
      array_length(p_rows, 1), v_ncols;
  END IF;
  v_md := '| ' || array_to_string(p_headers, ' | ') || E' |\n';
  v_sep := '|';
  FOR i IN 1..v_ncols LOOP
    v_sep := v_sep || ' --- |';
  END LOOP;
  v_md := v_md || v_sep || E'\n';
  IF p_rows IS NOT NULL AND array_length(p_rows, 1) > 0 THEN
    v_nrows := array_length(p_rows, 1) / v_ncols;
    FOR i IN 0..v_nrows - 1 LOOP
      v_md := v_md || '| ' || array_to_string(p_rows[i * v_ncols + 1 : (i + 1) * v_ncols], ' | ') || E' |\n';
    END LOOP;
  END IF;
  RETURN '<figure><md' || CASE WHEN p_page_size > 0 THEN ' data-page="' || p_page_size || '"' ELSE '' END || '>' || v_md || '</md></figure>';
END;
$function$;
