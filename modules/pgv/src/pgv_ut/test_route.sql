CREATE OR REPLACE FUNCTION pgv_ut.test_route()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_item jsonb;
  v_href text;
  v_html text;
  v_rpc text;
  v_schema text := 'pgv_qa';
  v_fname text;
BEGIN
  -- All nav pages render
  FOR v_item IN SELECT * FROM jsonb_array_elements(pgv_qa.nav_items()) LOOP
    v_href := v_item->>'href';
    IF v_href ~ '^https?://' THEN CONTINUE; END IF;
    v_html := pgv.route(v_schema, v_href, 'GET');
    RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 0,
      format('route %s %s renders HTML', v_schema, v_href));
    RETURN NEXT ok(v_html LIKE '%<nav%',
      format('route %s %s has nav', v_schema, v_href));
    RETURN NEXT ok(v_html LIKE '%<main%',
      format('route %s %s has main', v_schema, v_href));
  END LOOP;

  -- Nav pages exist as functions
  FOR v_item IN SELECT * FROM jsonb_array_elements(pgv_qa.nav_items()) LOOP
    v_href := v_item->>'href';
    IF v_href ~ '^https?://' THEN CONTINUE; END IF;
    IF v_href = '/' THEN v_fname := 'get_index';
    ELSE v_fname := 'get_' || replace(replace(trim(BOTH '/' FROM v_href), '/', '_'), '-', '_');
    END IF;
    RETURN NEXT ok(
      EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = v_schema AND p.proname = v_fname),
      format('nav %s -> %s.%s() exists', v_href, v_schema, v_fname));
  END LOOP;

  -- Nav hrefs prefixed with schema
  v_html := pgv.route(v_schema, '/', 'GET');
  RETURN NEXT ok(v_html LIKE '%href="/pgv_qa/"%', 'nav dashboard href prefixed');
  RETURN NEXT ok(v_html LIKE '%href="/pgv_qa/atoms"%', 'nav atoms href prefixed');
  RETURN NEXT ok(v_html LIKE '%href="/pgv_qa/forms"%', 'nav forms href prefixed');
  RETURN NEXT is(current_setting('pgv.route_prefix', true), '/pgv_qa', 'route_prefix set after route call');

  -- RPC targets exist
  FOR v_item IN SELECT * FROM jsonb_array_elements(pgv_qa.nav_items()) LOOP
    v_href := v_item->>'href';
    IF v_href ~ '^https?://' THEN CONTINUE; END IF;
    v_html := pgv.route(v_schema, v_href, 'GET');
    FOR v_rpc IN SELECT (regexp_matches(v_html, 'data-rpc="([^"]+)"', 'g'))[1] LOOP
      RETURN NEXT ok(
        EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = v_schema AND p.proname = v_rpc),
        format('data-rpc="%s" on %s -> %s.%s() exists', v_rpc, v_href, v_schema, v_rpc));
    END LOOP;
  END LOOP;

  -- Typed dispatch
  EXECUTE $x$
    CREATE OR REPLACE FUNCTION pgv_qa.get_test_param(p_id integer)
    RETURNS text LANGUAGE sql AS $f$ SELECT '<p>ID=' || $1::text || '</p>'; $f$
  $x$;
  v_html := pgv.route(v_schema, '/test-param', 'GET', '{"p_id": "42"}'::jsonb);
  RETURN NEXT ok(v_html LIKE '%ID=42%', 'route dispatches get_ with scalar int param');
  RETURN NEXT ok(v_html LIKE '%<nav%', 'scalar param page has layout');

  v_html := pgv.route(v_schema, '/atoms', 'GET');
  RETURN NEXT ok(v_html LIKE '%pgv-badge%', 'route dispatches get_ with 0 args');

  EXECUTE $x$
    CREATE OR REPLACE FUNCTION pgv_qa.post_test_action()
    RETURNS text LANGUAGE sql AS $f$ SELECT '<template data-toast="success">Done</template>'; $f$
  $x$;
  v_html := pgv.route(v_schema, '/test-action', 'POST');
  RETURN NEXT ok(v_html LIKE '%data-toast%', 'POST returns toast template');
  RETURN NEXT ok(v_html NOT LIKE '%<nav%', 'POST has no layout wrapping');

  DROP FUNCTION pgv_qa.get_test_param(integer);
  DROP FUNCTION pgv_qa.post_test_action();
END;
$function$;
