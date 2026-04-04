CREATE OR REPLACE FUNCTION pgv_ut.test_href()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(pgv.href('https://example.com') = 'https://example.com', 'href passes https');
  RETURN NEXT ok(pgv.href('http://example.com') = 'http://example.com', 'href passes http');
  RETURN NEXT ok(pgv.href('//example.com') = '//example.com', 'href passes protocol-relative');
  RETURN NEXT ok(pgv.href('mailto:a@b.com') = 'mailto:a@b.com', 'href passes mailto');
  RETURN NEXT ok(pgv.href('tel:+33123') = 'tel:+33123', 'href passes tel');

  RETURN NEXT throws_ok(
    $$SELECT pgv.href('/atoms')$$,
    'P0001',
    'pgv.href() is for external URLs only — use pgv.call_ref() for internal links. Got: /atoms',
    'href RAISEs on internal path /atoms'
  );
  RETURN NEXT throws_ok(
    $$SELECT pgv.href('/')$$,
    'P0001',
    'pgv.href() is for external URLs only — use pgv.call_ref() for internal links. Got: /',
    'href RAISEs on internal path /'
  );
END;
$function$;
