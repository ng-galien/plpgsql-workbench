CREATE OR REPLACE FUNCTION hr.absence_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT to_jsonb(a) || jsonb_build_object(
      'employee_name', e.prenom || ' ' || e.nom,
      'type_label', hr.absence_label(a.type_absence)
    )
    FROM hr.absence a
    JOIN hr.employee e ON e.id = a.employee_id
    WHERE a.tenant_id = current_setting('app.tenant_id', true)
    ORDER BY a.date_debut DESC;
END;
$function$;
