CREATE OR REPLACE FUNCTION pgv_ut.test_filter_form()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v text;
BEGIN
  -- Basic output
  v := pgv.filter_form(pgv.input('p_status', 'text', 'Statut'));
  RETURN NEXT ok(v LIKE '%data-filter%', 'has data-filter attribute');
  RETURN NEXT ok(v LIKE '%pgv-filter-bar%', 'form has filter-bar class');
  RETURN NEXT ok(v LIKE '%pgv-filter-inputs%', 'wraps inputs in filter-inputs');
  RETURN NEXT ok(v LIKE '%pgv-filter-submit%', 'submit has filter-submit class');
  RETURN NEXT ok(v LIKE '%type="submit"%', 'has submit button');
  RETURN NEXT ok(v NOT LIKE '%data-rpc%', 'no data-rpc attribute');
  RETURN NEXT ok(v LIKE '%name="p_status"%', 'body content preserved');
  RETURN NEXT ok(v LIKE '%pgv-filter-chips%', 'has chips container');
  RETURN NEXT ok(v LIKE '%<div class="pgv-filter">%', 'has filter wrapper');

  -- Default label uses i18n
  RETURN NEXT ok(v LIKE '%' || pgv.t('pgv.filter') || '%', 'default label uses i18n filter key');

  -- Custom submit label
  v := pgv.filter_form('<input name="q">', 'Rechercher');
  RETURN NEXT ok(v LIKE '%Rechercher%', 'custom submit label');
  RETURN NEXT ok(v NOT LIKE '%' || pgv.t('pgv.filter') || '%', 'custom label replaces default');

  -- Multiple inputs
  v := pgv.filter_form(pgv.input('a', 'text', 'A') || pgv.sel('b', 'B', '["x","y"]'::jsonb));
  RETURN NEXT ok(v LIKE '%name="a"%', 'first input present');
  RETURN NEXT ok(v LIKE '%name="b"%', 'second input present');

  -- Submit label is escaped
  v := pgv.filter_form('', 'A&B');
  RETURN NEXT ok(v LIKE '%A&amp;B%', 'submit label is escaped');
END;
$function$;
