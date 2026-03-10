CREATE OR REPLACE FUNCTION pgv_ut.test_action_data_contract()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v text;
BEGIN
  v := pgv.action('do_thing', 'Click', '{"id":1}'::jsonb, 'Sure?');
  RETURN NEXT ok(v LIKE '%data-rpc="do_thing"%', 'action has data-rpc');
  RETURN NEXT ok(v LIKE '%data-params%',         'action has data-params');
  RETURN NEXT ok(v LIKE '%data-confirm="Sure?"%', 'action has data-confirm');
END;
$function$;
