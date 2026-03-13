CREATE OR REPLACE FUNCTION pgv_ut.test_form_dialog()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v text;
BEGIN
  -- Basic output
  v := pgv.form_dialog('dlg1', 'Titre', '<input name="x">', 'post_foo');
  RETURN NEXT ok(v LIKE '%data-form-dialog="dlg1"%', 'trigger button has data-form-dialog');
  RETURN NEXT ok(v LIKE '%<dialog id="dlg1"%', 'dialog has correct id');
  RETURN NEXT ok(v LIKE '%class="pgv-form-dialog"%', 'dialog has pgv-form-dialog class');
  RETURN NEXT ok(v LIKE '%data-rpc="post_foo"%', 'form has data-rpc');
  RETURN NEXT ok(v LIKE '%data-dialog-form%', 'form has data-dialog-form marker');
  RETURN NEXT ok(v LIKE '%pgv-form-dialog-article%', 'article class present');
  RETURN NEXT ok(v LIKE '%pgv-form-dialog-header%', 'header class present');
  RETURN NEXT ok(v LIKE '%pgv-form-dialog-close%', 'close button class present');
  RETURN NEXT ok(v LIKE '%pgv-form-dialog-body%', 'body class present');
  RETURN NEXT ok(v LIKE '%pgv-form-dialog-footer%', 'footer class present');
  RETURN NEXT ok(v LIKE '%<input name="x">%', 'body content preserved');

  -- Title escaping
  v := pgv.form_dialog('d2', 'A&B', '', 'rpc');
  RETURN NEXT ok(v LIKE '%A&amp;B%', 'title is escaped');

  -- Custom label
  v := pgv.form_dialog('d3', 'Title', '', 'rpc', 'Click me');
  RETURN NEXT ok(v LIKE '%>Click me</button>%', 'custom label on trigger');

  -- Variant outline
  v := pgv.form_dialog('d4', 'T', '', 'rpc', NULL, 'outline');
  RETURN NEXT ok(v LIKE '%class="outline"%', 'outline variant applied');

  -- Variant secondary
  v := pgv.form_dialog('d5', 'T', '', 'rpc', NULL, 'secondary');
  RETURN NEXT ok(v LIKE '%class="secondary"%', 'secondary variant applied');

  -- data-src for lazy load
  v := pgv.form_dialog('d6', 'T', '', 'rpc', NULL, NULL, '/edit_form?id=1');
  RETURN NEXT ok(v LIKE '%data-src="/edit_form?id=1"%', 'data-src attribute present');

  -- No data-src when NULL
  v := pgv.form_dialog('d7', 'T', '', 'rpc');
  RETURN NEXT ok(v NOT LIKE '%data-src%', 'no data-src when p_src is NULL');

  -- i18n: cancel and send buttons
  v := pgv.form_dialog('d8', 'T', '', 'rpc');
  RETURN NEXT ok(v LIKE '%' || pgv.t('cancel') || '%', 'cancel button uses i18n');
  RETURN NEXT ok(v LIKE '%' || pgv.t('send') || '%', 'send button uses i18n');
END;
$function$;
