CREATE OR REPLACE FUNCTION pgv_ut.test_radio()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := pgv.radio('freq', 'Frequence', '["jour", "semaine", "mois"]'::jsonb, 'semaine');
  RETURN NEXT ok(v_html LIKE '%type="radio"%', 'radio has type');
  RETURN NEXT ok(v_html LIKE '%name="freq"%', 'radio has name');
  RETURN NEXT ok(v_html LIKE '%checked%', 'radio has selected option');
  RETURN NEXT ok(v_html LIKE '%jour%', 'radio has first option');
  RETURN NEXT ok(v_html LIKE '%mois%', 'radio has last option');
END;
$function$;
