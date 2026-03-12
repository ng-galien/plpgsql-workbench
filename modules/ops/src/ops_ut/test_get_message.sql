CREATE OR REPLACE FUNCTION ops_ut.test_get_message()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_id int;
BEGIN
  -- Get a real message id
  SELECT id INTO v_id FROM workbench.agent_message ORDER BY created_at DESC LIMIT 1;

  IF v_id IS NOT NULL THEN
    v_html := ops.get_message(v_id);
    RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 0, 'get_message renders HTML for existing msg');
    RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'get_message shows stat widgets');
    RETURN NEXT ok(v_html LIKE '%breadcrumb%' OR v_html LIKE '%Messages%', 'get_message has breadcrumb');
    RETURN NEXT ok(v_html NOT LIKE '%style="%', 'get_message has no inline styles');
  ELSE
    RETURN NEXT ok(true, 'no messages in DB — skip detail test');
  END IF;

  -- Not found
  v_html := ops.get_message(-999);
  RETURN NEXT ok(v_html LIKE '%pgv-empty%', 'get_message(-999) shows empty state');
END;
$function$;
