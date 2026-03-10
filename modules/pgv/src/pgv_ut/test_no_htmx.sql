CREATE OR REPLACE FUNCTION pgv_ut.test_no_htmx()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v text;
BEGIN
  v := pgv.badge('x') || pgv.stat('l','v') || pgv.card('t','b')
    || pgv.action('fn', 'btn', NULL::jsonb) || pgv.error('400','err')
    || pgv.nav('B', '[{"href":"/","label":"H"}]'::jsonb, '/');
  RETURN NEXT ok(
    v NOT LIKE '%hx-get%' AND v NOT LIKE '%hx-post%'
    AND v NOT LIKE '%hx-target%' AND v NOT LIKE '%hx-swap%'
    AND v NOT LIKE '%hx-vals%' AND v NOT LIKE '%hx-trigger%',
    'zero hx-* attributes in pgv output'
  );
END;
$function$;
