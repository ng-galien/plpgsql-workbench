CREATE OR REPLACE FUNCTION planning.worker_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE v_row planning.worker; v_result jsonb;
BEGIN
  SELECT * INTO v_row FROM planning.worker WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RETURN NULL; END IF;
  v_result := to_jsonb(v_row) || jsonb_build_object(
    'active_event_count', (SELECT count(*)::int FROM planning.assignment a JOIN planning.event e ON e.id = a.event_id WHERE a.worker_id = v_row.id AND e.end_date >= current_date),
    'events', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'type', e.type, 'start_date', e.start_date, 'end_date', e.end_date, 'location', e.location) ORDER BY e.start_date) FROM planning.event e JOIN planning.assignment a ON a.event_id = e.id WHERE a.worker_id = v_row.id AND e.end_date >= current_date), '[]'::jsonb)
  );
  IF v_row.active THEN
    v_result := v_result || jsonb_build_object('actions', jsonb_build_array(jsonb_build_object('method', 'deactivate', 'uri', 'planning://worker/' || p_id || '/deactivate'), jsonb_build_object('method', 'delete', 'uri', 'planning://worker/' || p_id)));
  ELSE
    v_result := v_result || jsonb_build_object('actions', jsonb_build_array(jsonb_build_object('method', 'activate', 'uri', 'planning://worker/' || p_id || '/activate'), jsonb_build_object('method', 'delete', 'uri', 'planning://worker/' || p_id)));
  END IF;
  RETURN v_result;
END;
$function$;
