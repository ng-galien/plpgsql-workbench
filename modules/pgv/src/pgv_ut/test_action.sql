CREATE OR REPLACE FUNCTION pgv_ut.test_action()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := pgv.action('save', 'Sauvegarder');
  RETURN NEXT ok(v_html LIKE '%data-rpc="save"%', 'action has data-rpc');

  v_html := pgv.action('del', 'Supprimer', '{"id":1}'::jsonb);
  RETURN NEXT ok(v_html LIKE '%data-params%', 'action has data-params');

  v_html := pgv.action('del', 'Supprimer', NULL::jsonb, 'Etes-vous sur?');
  RETURN NEXT ok(v_html LIKE '%data-confirm%', 'action has data-confirm');
END;
$function$;
