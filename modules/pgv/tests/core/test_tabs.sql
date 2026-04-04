CREATE OR REPLACE FUNCTION pgv_ut.test_tabs()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := pgv.tabs('Tab1', '<p>Content1</p>', 'Tab2', '<p>Content2</p>');
  RETURN NEXT ok(v_html LIKE '%pgv-tabs-nav%', 'tabs has nav class');
  RETURN NEXT ok(v_html LIKE '%x-data%', 'tabs has Alpine x-data');
  RETURN NEXT ok(v_html LIKE '%Tab1%', 'tabs has first label');
  RETURN NEXT ok(v_html LIKE '%Content2%', 'tabs has second content');
END;
$function$;
