CREATE OR REPLACE FUNCTION pgv_ut.test_nav()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  PERFORM set_config('pgv.route_prefix', '/test', true);
  v_html := pgv.nav('Test', '[
    {"href": "/test/", "label": "Home"},
    {"href": "https://example.com", "label": "External"}
  ]'::jsonb, '/test/');

  -- Theme toggle
  RETURN NEXT ok(v_html LIKE '%data-toggle-theme%', 'nav has theme toggle');
  RETURN NEXT ok(v_html LIKE '%pgv-theme-toggle%', 'theme toggle has CSS class');

  -- External link
  RETURN NEXT ok(v_html LIKE '%target="_blank"%', 'external link has target=_blank');
  RETURN NEXT ok(v_html LIKE '%rel="noopener"%', 'external link has rel=noopener');
  RETURN NEXT ok(v_html LIKE '%href="https://example.com"%', 'external href preserved');

  -- Current page
  RETURN NEXT ok(v_html LIKE '%aria-current="page"%', 'current page has aria-current');

  -- No htmx
  RETURN NEXT ok(v_html NOT LIKE '%hx-%', 'nav has no hx-* attributes');
END;
$function$;
