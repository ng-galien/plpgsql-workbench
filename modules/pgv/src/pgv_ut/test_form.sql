CREATE OR REPLACE FUNCTION pgv_ut.test_form()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v text;
BEGIN
  v := pgv.form('save_client', '<input name="name" value="test">');
  RETURN NEXT ok(v ~ '<form data-rpc="save_client">', 'form has data-rpc');
  RETURN NEXT ok(v ~ '<input name="name"', 'body preserved');
  RETURN NEXT ok(v ~ '<button type="submit">', 'has submit button');
  RETURN NEXT ok(v ~ '</button></form>', 'properly closed');

  -- Custom submit label
  v := pgv.form('delete', '<p>Sure?</p>', 'Supprimer');
  RETURN NEXT ok(v ~ '>Supprimer</button>', 'custom submit label');

  -- XSS on rpc name
  v := pgv.form('" onclick="alert(1)', '');
  RETURN NEXT ok(v ~ '&quot;', 'quotes escaped in rpc name');
END;
$function$;
