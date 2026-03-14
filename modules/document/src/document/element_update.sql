CREATE OR REPLACE FUNCTION document.element_update(p_element_id uuid, p_props_patch jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE document.element SET
    x            = COALESCE((p_props_patch->>'x')::real, x),
    y            = COALESCE((p_props_patch->>'y')::real, y),
    width        = COALESCE((p_props_patch->>'width')::real, width),
    height       = COALESCE((p_props_patch->>'height')::real, height),
    x1           = COALESCE((p_props_patch->>'x1')::real, x1),
    y1           = COALESCE((p_props_patch->>'y1')::real, y1),
    x2           = COALESCE((p_props_patch->>'x2')::real, x2),
    y2           = COALESCE((p_props_patch->>'y2')::real, y2),
    cx           = COALESCE((p_props_patch->>'cx')::real, cx),
    cy           = COALESCE((p_props_patch->>'cy')::real, cy),
    r            = COALESCE((p_props_patch->>'r')::real, r),
    rx_          = COALESCE((p_props_patch->>'rx')::real, rx_),
    ry_          = COALESCE((p_props_patch->>'ry')::real, ry_),
    opacity      = COALESCE((p_props_patch->>'opacity')::real, opacity),
    rotation     = COALESCE((p_props_patch->>'rotation')::real, rotation),
    fill         = COALESCE(p_props_patch->>'fill', fill),
    stroke       = COALESCE(p_props_patch->>'stroke', stroke),
    stroke_width = COALESCE((p_props_patch->>'stroke_width')::real, stroke_width),
    stroke_dasharray = COALESCE(p_props_patch->>'stroke_dasharray', stroke_dasharray),
    name         = COALESCE(p_props_patch->>'name', name),
    sort_order   = COALESCE((p_props_patch->>'sort_order')::int, sort_order),
    parent_id    = CASE WHEN p_props_patch ? 'parent_id' THEN (p_props_patch->>'parent_id')::uuid ELSE parent_id END,
    props        = props || (p_props_patch - ARRAY['x','y','width','height','x1','y1','x2','y2',
                   'cx','cy','r','rx','ry','opacity','rotation','fill','stroke',
                   'stroke_width','stroke_dasharray','name','sort_order','parent_id','asset_id'])
  WHERE id = p_element_id
    AND tenant_id = current_setting('app.tenant_id', true);
END;
$function$;
