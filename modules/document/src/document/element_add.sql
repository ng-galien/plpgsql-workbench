CREATE OR REPLACE FUNCTION document.element_add(p_canvas_id uuid, p_type text, p_sort_order integer DEFAULT 0, p_props jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO document.element (
    canvas_id, type, sort_order,
    parent_id, name,
    x, y, width, height,
    x1, y1, x2, y2,
    cx, cy, r, rx_, ry_,
    opacity, rotation, fill, stroke, stroke_width, stroke_dasharray,
    asset_id, props, tenant_id
  ) VALUES (
    p_canvas_id, p_type, p_sort_order,
    (p_props->>'parent_id')::uuid,
    p_props->>'name',
    (p_props->>'x')::real, (p_props->>'y')::real,
    (p_props->>'width')::real, (p_props->>'height')::real,
    (p_props->>'x1')::real, (p_props->>'y1')::real,
    (p_props->>'x2')::real, (p_props->>'y2')::real,
    (p_props->>'cx')::real, (p_props->>'cy')::real,
    (p_props->>'r')::real, (p_props->>'rx')::real, (p_props->>'ry')::real,
    COALESCE((p_props->>'opacity')::real, 1),
    COALESCE((p_props->>'rotation')::real, 0),
    p_props->>'fill', p_props->>'stroke',
    (p_props->>'stroke_width')::real, p_props->>'stroke_dasharray',
    (p_props->>'asset_id')::uuid,
    p_props - ARRAY['parent_id','name','x','y','width','height','x1','y1','x2','y2',
                     'cx','cy','r','rx','ry','opacity','rotation','fill','stroke',
                     'stroke_width','stroke_dasharray','asset_id'],
    current_setting('app.tenant_id', true)
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;
