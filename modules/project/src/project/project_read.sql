CREATE OR REPLACE FUNCTION project.project_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE v_row jsonb; v_status text; v_actions jsonb := '[]'::jsonb; v_uri text;
BEGIN
  SELECT to_jsonb(p) || jsonb_build_object('client_name', cl.name, 'estimate_code', q.numero,
    'progress', project._global_progress(p.id),
    'total_hours', (SELECT COALESCE(sum(hours), 0) FROM project.time_entry WHERE project_id = p.id),
    'milestone_count', (SELECT count(*) FROM project.milestone WHERE project_id = p.id)
  ) INTO v_row FROM project.project p JOIN crm.client cl ON cl.id = p.client_id
  LEFT JOIN quote.devis q ON q.id = p.estimate_id
  WHERE p.id = p_id::int AND p.tenant_id = current_setting('app.tenant_id', true);
  IF v_row IS NULL THEN RETURN NULL; END IF;
  v_status := v_row ->> 'status'; v_uri := 'project://project/' || p_id;
  CASE v_status
    WHEN 'draft' THEN v_actions := jsonb_build_array(jsonb_build_object('method','start','uri',v_uri||'/start'), jsonb_build_object('method','edit','uri',v_uri), jsonb_build_object('method','delete','uri',v_uri||'/delete'));
    WHEN 'active' THEN v_actions := jsonb_build_array(jsonb_build_object('method','review','uri',v_uri||'/review'), jsonb_build_object('method','edit','uri',v_uri));
    WHEN 'review' THEN v_actions := jsonb_build_array(jsonb_build_object('method','close','uri',v_uri||'/close'));
    ELSE v_actions := '[]'::jsonb;
  END CASE;
  RETURN v_row || jsonb_build_object('actions', v_actions);
END;
$function$;
