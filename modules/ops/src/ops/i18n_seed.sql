CREATE OR REPLACE FUNCTION ops.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'ops.brand', 'Ops'),
    ('fr', 'ops.nav_agents', 'Agents'),
    ('fr', 'ops.nav_modules', 'Modules'),
    ('fr', 'ops.nav_tests', 'Tests'),
    ('fr', 'ops.nav_health', 'Santé'),
    ('fr', 'ops.nav_hooks', 'Hooks'),
    ('fr', 'ops.nav_docs', 'Docs')
  ON CONFLICT DO NOTHING;
END;
$function$;
