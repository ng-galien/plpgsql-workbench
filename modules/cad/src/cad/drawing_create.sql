CREATE OR REPLACE FUNCTION cad.drawing_create(p_row cad.drawing)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.dimension := COALESCE(p_row.dimension, '2d');
  p_row.created_at := now();
  p_row.updated_at := now();

  INSERT INTO cad.drawing (name, scale, unit, width, height, dimension, tenant_id, created_at, updated_at)
  VALUES (p_row.name, COALESCE(p_row.scale, 1.0), COALESCE(p_row.unit, 'mm'),
          COALESCE(p_row.width, 2000), COALESCE(p_row.height, 1500),
          p_row.dimension, p_row.tenant_id, p_row.created_at, p_row.updated_at)
  RETURNING * INTO p_row;

  INSERT INTO cad.layer (drawing_id, name, color, stroke_width)
  VALUES (p_row.id, 'Structure', '#333333', 1.5);

  RETURN to_jsonb(p_row);
END;
$function$;
