CREATE OR REPLACE FUNCTION pgv_ut.test_route_typed_dispatch()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  -- Test GET with scalar param: get_test_param(p_id int) should be callable
  -- First create a temporary test function
  EXECUTE $x$
    CREATE OR REPLACE FUNCTION pgv_qa.get_test_param(p_id integer)
    RETURNS text LANGUAGE sql AS $f$
      SELECT '<p>ID=' || $1::text || '</p>';
    $f$
  $x$;

  v_html := pgv.route('pgv_qa', '/test-param', 'GET', '{"p_id": "42"}'::jsonb);
  RETURN NEXT ok(v_html LIKE '%ID=42%', 'route dispatches get_ with scalar int param');
  RETURN NEXT ok(v_html LIKE '%<nav%', 'scalar param page has layout');

  -- Test GET with 0 args still works
  v_html := pgv.route('pgv_qa', '/atoms', 'GET');
  RETURN NEXT ok(v_html LIKE '%pgv-badge%', 'route dispatches get_ with 0 args');

  -- Test POST returns raw (no layout)
  EXECUTE $x$
    CREATE OR REPLACE FUNCTION pgv_qa.post_test_action()
    RETURNS text LANGUAGE sql AS $f$
      SELECT '<template data-toast="success">Done</template>';
    $f$
  $x$;

  v_html := pgv.route('pgv_qa', '/test-action', 'POST');
  RETURN NEXT ok(v_html LIKE '%data-toast%', 'POST returns toast template');
  RETURN NEXT ok(v_html NOT LIKE '%<nav%', 'POST has no layout wrapping');

  -- Cleanup
  DROP FUNCTION pgv_qa.get_test_param(integer);
  DROP FUNCTION pgv_qa.post_test_action();
END;
$function$;
