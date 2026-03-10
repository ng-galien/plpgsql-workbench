CREATE OR REPLACE FUNCTION pgv_ut.test_dl_css_class()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(
    pgv.dl('k', 'v') LIKE '%class="pgv-dl"%',
    'dl outputs class pgv-dl'
  );
END;
$function$;
