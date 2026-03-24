CREATE OR REPLACE FUNCTION hr.absence_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT to_jsonb(a) || jsonb_build_object(
    'employee_name', e.prenom || ' ' || e.nom,
    'type_label', hr.absence_label(a.type_absence)
  ) INTO v_result
  FROM hr.absence a
  JOIN hr.employee e ON e.id = a.employee_id
  WHERE a.id = p_id::int AND a.tenant_id = current_setting('app.tenant_id', true);

  RETURN v_result;
END;
$function$;
