CREATE OR REPLACE FUNCTION docs.charte_create(p_data docs.charte)
 RETURNS docs.charte
 LANGUAGE plpgsql
AS $function$
BEGIN
  p_data.id := gen_random_uuid()::text;
  p_data.tenant_id := current_setting('app.tenant_id', true);
  p_data.slug := pgv.slugify(p_data.name);
  p_data.color_extra := COALESCE(p_data.color_extra, '{}'::jsonb);
  p_data.rules := COALESCE(p_data.rules, '{}'::jsonb);
  p_data.created_at := now();
  p_data.updated_at := now();
  INSERT INTO docs.charte VALUES (p_data.*) RETURNING * INTO p_data;
  RETURN p_data;
END;
$function$;
