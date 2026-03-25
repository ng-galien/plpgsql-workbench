CREATE OR REPLACE FUNCTION project.project_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(p) || jsonb_build_object('client_name', cl.name, 'estimate_code', q.numero, 'progress', project._global_progress(p.id))
      FROM project.project p JOIN crm.client cl ON cl.id = p.client_id LEFT JOIN quote.devis q ON q.id = p.estimate_id
      WHERE p.tenant_id = current_setting('app.tenant_id', true) ORDER BY p.updated_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(p) || jsonb_build_object(''client_name'', cl.name, ''estimate_code'', q.numero, ''progress'', project._global_progress(p.id))
       FROM project.project p JOIN crm.client cl ON cl.id = p.client_id LEFT JOIN quote.devis q ON q.id = p.estimate_id
       WHERE p.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'project', 'project') || ' ORDER BY p.updated_at DESC';
  END IF;
END;
$function$;
