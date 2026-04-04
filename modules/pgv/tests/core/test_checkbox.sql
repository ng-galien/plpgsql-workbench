CREATE OR REPLACE FUNCTION pgv_ut.test_checkbox()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := pgv.checkbox('notify', 'Notifications');
  RETURN NEXT ok(v_html LIKE '%type="checkbox"%', 'checkbox has type');
  RETURN NEXT ok(v_html LIKE '%name="notify"%', 'checkbox has name');
  RETURN NEXT ok(v_html LIKE '%Notifications%', 'checkbox has label');
  RETURN NEXT ok(v_html NOT LIKE '%checked%', 'checkbox unchecked by default');

  v_html := pgv.checkbox('agree', 'Accept', true);
  RETURN NEXT ok(v_html LIKE '%checked%', 'checkbox checked when p_checked=true');
END;
$function$;
