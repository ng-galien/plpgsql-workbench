CREATE OR REPLACE FUNCTION project_ut.test_pages_render()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cid int;
  v_html text;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  PERFORM set_config('pgv.route_prefix', '/project', true);

  -- brand & nav
  RETURN NEXT is(project.brand(), 'Chantiers', 'brand returns Chantiers');
  RETURN NEXT ok(project.nav_items() IS NOT NULL, 'nav_items returns jsonb');

  -- get_index
  v_html := project.get_index();
  RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 50, 'get_index renders');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'get_index has stats');

  -- get_chantiers
  v_html := project.get_chantiers();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_chantiers renders');

  -- get_chantier with seed data
  SELECT id INTO v_cid FROM project.chantier LIMIT 1;
  IF v_cid IS NOT NULL THEN
    v_html := project.get_chantier(v_cid);
    RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 100, 'get_chantier renders');
    RETURN NEXT ok(v_html LIKE '%pgv-tabs%', 'get_chantier has tabs');
    RETURN NEXT ok(v_html LIKE '%/crm/client%', 'get_chantier has crm link');
  END IF;

  -- get_chantier_form
  v_html := project.get_chantier_form();
  RETURN NEXT ok(v_html LIKE '%data-rpc="post_chantier_save"%', 'chantier_form has rpc');

  -- get_chantier not found
  v_html := project.get_chantier(-1);
  RETURN NEXT ok(v_html LIKE '%introuvable%', 'get_chantier -1 returns empty');
END;
$function$;
