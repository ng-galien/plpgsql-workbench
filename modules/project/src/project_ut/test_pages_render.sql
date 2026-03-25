CREATE OR REPLACE FUNCTION project_ut.test_pages_render()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_html text; v_pid int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  PERFORM set_config('pgv.route_prefix', '/project', true);
  RETURN NEXT is(project.brand(), 'Projets', 'brand returns Projets');
  RETURN NEXT ok(project.nav_items() IS NOT NULL, 'nav_items returns jsonb');
  v_html := project.get_index();
  RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 50, 'get_index renders');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'get_index has stats');
  v_html := project.get_projects();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_projects renders');
  SELECT id INTO v_pid FROM project.project LIMIT 1;
  IF v_pid IS NOT NULL THEN
    v_html := project.get_project(v_pid);
    RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 50, 'get_project renders');
  END IF;
  v_html := project.get_project(-1);
  RETURN NEXT ok(v_html LIKE '%pgv-empty%', 'get_project -1 returns empty');
  v_html := project.get_planning();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_planning renders');
END;
$function$;
