CREATE OR REPLACE FUNCTION pgv_ut.test_toggle()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := pgv.toggle('dark', 'Dark mode');
  RETURN NEXT ok(v_html LIKE '%role="switch"%', 'toggle has role=switch');
  RETURN NEXT ok(v_html LIKE '%name="dark"%', 'toggle has name');
  RETURN NEXT ok(v_html NOT LIKE '%checked%', 'toggle unchecked by default');

  v_html := pgv.toggle('auto', 'Auto', true);
  RETURN NEXT ok(v_html LIKE '%checked%', 'toggle checked when p_checked=true');
END;
$function$;
