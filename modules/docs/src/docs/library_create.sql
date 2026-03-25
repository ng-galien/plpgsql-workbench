CREATE OR REPLACE FUNCTION docs.library_create(p_data docs.library)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_data.id := gen_random_uuid()::text;
  p_data.tenant_id := current_setting('app.tenant_id', true);
  p_data.slug := pgv.slugify(p_data.name);
  p_data.created_at := now();
  INSERT INTO docs.library VALUES (p_data.*) RETURNING * INTO p_data;
  RETURN to_jsonb(p_data);
END;
$function$;
