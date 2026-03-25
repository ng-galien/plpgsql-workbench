CREATE OR REPLACE FUNCTION cad.drawing_update(p_row cad.drawing)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE cad.drawing SET
    name = COALESCE(NULLIF(p_row.name, ''), name),
    scale = COALESCE(p_row.scale, scale),
    unit = COALESCE(NULLIF(p_row.unit, ''), unit),
    width = COALESCE(p_row.width, width),
    height = COALESCE(p_row.height, height),
    dimension = COALESCE(NULLIF(p_row.dimension, ''), dimension),
    updated_at = now()
  WHERE id = p_row.id
    AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
