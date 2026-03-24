CREATE OR REPLACE FUNCTION hr.employee_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT to_jsonb(e) || jsonb_build_object(
      'contrat_label', hr.contrat_label(e.type_contrat),
      'display_name', e.prenom || ' ' || e.nom
    )
    FROM hr.employee e
    WHERE e.tenant_id = current_setting('app.tenant_id', true)
    ORDER BY e.nom, e.prenom;
END;
$function$;
