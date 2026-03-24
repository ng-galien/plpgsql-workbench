CREATE OR REPLACE FUNCTION project.chantier_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(c) || jsonb_build_object(
        'client_name', cl.name,
        'devis_numero', d.numero,
        'avancement', project._avancement_global(c.id)
      )
      FROM project.chantier c
      JOIN crm.client cl ON cl.id = c.client_id
      LEFT JOIN quote.devis d ON d.id = c.devis_id
      WHERE c.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY c.updated_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(c) || jsonb_build_object(
        ''client_name'', cl.name,
        ''devis_numero'', d.numero,
        ''avancement'', project._avancement_global(c.id)
      )
      FROM project.chantier c
      JOIN crm.client cl ON cl.id = c.client_id
      LEFT JOIN quote.devis d ON d.id = c.devis_id
      WHERE c.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
      || ' AND ' || pgv.rsql_to_where(p_filter, 'project', 'chantier')
      || ' ORDER BY c.updated_at DESC';
  END IF;
END;
$function$;
