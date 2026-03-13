CREATE OR REPLACE FUNCTION pgv_ut.test_toast()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v text;
BEGIN
  v := pgv.toast('Saved!');
  RETURN NEXT ok(v ~ '<template data-toast="success">', 'default level is success');
  RETURN NEXT ok(v ~ '>Saved!</template>', 'message content');

  v := pgv.toast('Erreur!', 'error');
  RETURN NEXT ok(v ~ 'data-toast="error"', 'error level');
  RETURN NEXT ok(v ~ '>Erreur!</template>', 'error message');

  -- XSS safety
  v := pgv.toast('<script>alert(1)</script>');
  RETURN NEXT ok(v !~ '<script>', 'message is escaped');
END;
$function$;
