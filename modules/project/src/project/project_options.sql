CREATE OR REPLACE FUNCTION project.project_options(p_search text DEFAULT ''::text)
 RETURNS TABLE(value text, label text, detail text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT p.id::text, p.code || ' — ' || p.subject, pgv.esc(cl.name) || ' · ' || p.status
    FROM project.project p JOIN crm.client cl ON cl.id = p.client_id
    WHERE p.tenant_id = current_setting('app.tenant_id', true)
      AND (p_search = '' OR p.code ILIKE '%'||p_search||'%' OR p.subject ILIKE '%'||p_search||'%' OR cl.name ILIKE '%'||p_search||'%')
    ORDER BY p.updated_at DESC LIMIT 20;
END;
$function$;
