CREATE OR REPLACE FUNCTION project.get_projects(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE v_body text := ''; r record;
BEGIN
  FOR r IN SELECT * FROM project.project_list() LOOP
    v_body := v_body || format('<p><a href="%s">%s</a> — %s (%s)</p>',
      pgv.call_ref('get_project', jsonb_build_object('p_id', (r.project_list->>'id')::int)),
      pgv.esc(r.project_list->>'code'), pgv.esc(r.project_list->>'subject'), r.project_list->>'status');
  END LOOP;
  IF v_body = '' THEN v_body := pgv.empty(pgv.t('project.empty_none_active'), pgv.t('project.empty_create_first')); END IF;
  RETURN v_body;
END;
$function$;
