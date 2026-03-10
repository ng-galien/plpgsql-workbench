CREATE OR REPLACE FUNCTION pgv_ut.test_error_css_classes()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(
    pgv.error('404', 'Not found') LIKE '%class="pgv-error"%',
    'error outputs class pgv-error'
  );
  RETURN NEXT ok(
    pgv.error('404', 'Not found') NOT LIKE '%style=%',
    'error has no inline style'
  );
END;
$function$;
