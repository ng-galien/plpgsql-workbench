CREATE OR REPLACE FUNCTION docs.library_update(p_data docs.library)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF p_data.name IS NOT NULL AND p_data.name != '' THEN
    p_data.slug := pgv.slugify(p_data.name);
  END IF;

  UPDATE docs.library SET
    name = COALESCE(NULLIF(p_data.name, ''), name),
    slug = COALESCE(NULLIF(p_data.slug, ''), slug),
    description = COALESCE(p_data.description, description)
  WHERE (slug = p_data.slug OR id = p_data.id) AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_data;
  RETURN to_jsonb(p_data);
END;
$function$;
