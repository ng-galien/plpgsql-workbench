CREATE OR REPLACE FUNCTION pgv_ut.test_accordion()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := pgv.accordion('Section1', '<p>Body1</p>', 'Section2', '<p>Body2</p>');
  RETURN NEXT ok(v_html LIKE '%<details class="pgv-accordion">%', 'accordion uses details with class');
  RETURN NEXT ok(v_html LIKE '%<summary>Section1</summary>%', 'accordion has summary');
  RETURN NEXT ok(v_html LIKE '%Body2%', 'accordion has second body');
END;
$function$;
