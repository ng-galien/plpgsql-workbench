CREATE OR REPLACE FUNCTION pgv_ut.test_lazy()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  -- Basic lazy
  v_html := pgv.lazy('load_data');
  RETURN NEXT ok(v_html LIKE '%pgv-lazy%', 'lazy has pgv-lazy class');
  RETURN NEXT ok(v_html LIKE '%data-lazy="load_data"%', 'lazy has data-lazy attr');
  RETURN NEXT ok(v_html LIKE '%aria-busy="true"%', 'lazy has loading indicator');

  -- With params
  v_html := pgv.lazy('load_detail', '{"id": 42}'::jsonb);
  RETURN NEXT ok(v_html LIKE '%data-params%', 'lazy with params has data-params');
  RETURN NEXT ok(v_html LIKE '%"id": 42%', 'lazy params contain value');

  -- No params = no data-params attr
  v_html := pgv.lazy('simple_load', '{}'::jsonb);
  RETURN NEXT ok(v_html NOT LIKE '%data-params%', 'lazy with empty params omits data-params');

  -- XSS in rpc name
  v_html := pgv.lazy('"><script>');
  RETURN NEXT ok(v_html NOT LIKE '%<script>%', 'lazy escapes rpc name');
END;
$function$;
