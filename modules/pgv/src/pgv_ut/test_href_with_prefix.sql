CREATE OR REPLACE FUNCTION pgv_ut.test_href_with_prefix()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- External URLs pass through
  RETURN NEXT is(pgv.href('https://example.com'), 'https://example.com', 'href passes https');
  RETURN NEXT is(pgv.href('http://localhost:3000'), 'http://localhost:3000', 'href passes http');
  RETURN NEXT is(pgv.href('//cdn.example.com/lib.js'), '//cdn.example.com/lib.js', 'href passes protocol-relative');
  RETURN NEXT is(pgv.href('mailto:test@example.com'), 'mailto:test@example.com', 'href passes mailto');
  RETURN NEXT is(pgv.href('tel:+33123456789'), 'tel:+33123456789', 'href passes tel');

  -- Internal paths return NULL (use call_ref instead)
  RETURN NEXT is(pgv.href('/atoms'), NULL, 'href rejects internal path /atoms');
  RETURN NEXT is(pgv.href('/'), NULL, 'href rejects internal path /');
END;
$function$;
