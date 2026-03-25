CREATE OR REPLACE FUNCTION planning.event_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE v_row planning.event; v_result jsonb;
BEGIN
  SELECT * INTO v_row FROM planning.event WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RETURN NULL; END IF;
  v_result := to_jsonb(v_row) || jsonb_build_object(
    'project_code', (SELECT p.code FROM project.project p WHERE p.id = v_row.project_id),
    'workers', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', w.id, 'name', w.name, 'role', w.role, 'color', w.color) ORDER BY w.name) FROM planning.assignment a JOIN planning.worker w ON w.id = a.worker_id WHERE a.event_id = v_row.id), '[]'::jsonb)
  );
  v_result := v_result || jsonb_build_object('actions', jsonb_build_array(jsonb_build_object('method', 'delete', 'uri', 'planning://event/' || p_id)));
  RETURN v_result;
END;
$function$;
