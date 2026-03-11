CREATE OR REPLACE FUNCTION pgv_ut.test_md_table()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_ok boolean;
BEGIN
  -- Basic table
  v_html := pgv.md_table(ARRAY['A', 'B'], ARRAY['1', '2', '3', '4']);
  RETURN NEXT ok(v_html LIKE '%<md>%', 'md_table wraps in md tag');
  RETURN NEXT ok(v_html LIKE '%| A | B |%', 'md_table has headers');
  RETURN NEXT ok(v_html LIKE '%| 1 | 2 |%', 'md_table has first row');
  RETURN NEXT ok(v_html LIKE '%| 3 | 4 |%', 'md_table has second row');

  -- Empty rows
  v_html := pgv.md_table(ARRAY['X', 'Y'], NULL);
  RETURN NEXT ok(v_html LIKE '%| X | Y |%', 'md_table with null rows has headers');
  RETURN NEXT ok(v_html LIKE '%| --- |%', 'md_table with null rows has separator');

  -- Modulo assertion
  BEGIN
    v_html := pgv.md_table(ARRAY['A', 'B', 'C'], ARRAY['1', '2']);
    v_ok := false;
  EXCEPTION WHEN raise_exception THEN
    v_ok := true;
  END;
  RETURN NEXT ok(v_ok, 'md_table raises on non-multiple row count');
END;
$function$;
