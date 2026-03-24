CREATE OR REPLACE FUNCTION hr.employee_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT to_jsonb(e) || jsonb_build_object(
    'contrat_label', hr.contrat_label(e.type_contrat),
    'display_name', e.prenom || ' ' || e.nom
  ) INTO v_result
  FROM hr.employee e
  WHERE e.id = p_id::int AND e.tenant_id = current_setting('app.tenant_id', true);

  RETURN v_result;
END;
$function$;
