CREATE OR REPLACE FUNCTION pgv_ut.test_redirect()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v text;
BEGIN
  v := pgv.redirect('/clients');
  RETURN NEXT ok(v ~ '<template data-redirect="/clients">', 'redirect path');
  RETURN NEXT ok(v ~ '></template>', 'empty body');

  v := pgv.redirect('/client?id=42');
  RETURN NEXT ok(v ~ 'data-redirect="/client\?id=42"', 'query params preserved');

  -- XSS safety
  v := pgv.redirect('/"onload="alert(1)');
  RETURN NEXT ok(v ~ '&quot;', 'quotes escaped in path');
END;
$function$;
