CREATE OR REPLACE FUNCTION document.charte_list()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb := '[]'::jsonb;
  r record;
BEGIN
  FOR r IN
    SELECT id, name, description, color_bg, color_main, color_accent,
           font_heading, font_body, created_at
    FROM document.charte
    WHERE tenant_id = current_setting('app.tenant_id', true)
    ORDER BY name
  LOOP
    v_result := v_result || jsonb_build_object(
      'id', r.id,
      'name', r.name,
      'description', r.description,
      'colors', jsonb_build_object('bg', r.color_bg, 'main', r.color_main, 'accent', r.color_accent),
      'fonts', jsonb_build_object('heading', r.font_heading, 'body', r.font_body),
      'created_at', r.created_at
    );
  END LOOP;

  RETURN v_result;
END;
$function$;
