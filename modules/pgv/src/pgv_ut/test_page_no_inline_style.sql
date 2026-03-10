CREATE OR REPLACE FUNCTION pgv_ut.test_page_no_inline_style()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(
    pgv.page('Test', 'T', '/', '[]'::jsonb, '<p>x</p>') NOT LIKE '%style=%',
    'page has no inline style'
  );
END;
$function$;
