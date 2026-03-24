CREATE OR REPLACE FUNCTION project.chantier_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  DELETE FROM project.chantier
  WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING to_jsonb(project.chantier.*) INTO v_result;

  RETURN v_result;
END;
$function$;
