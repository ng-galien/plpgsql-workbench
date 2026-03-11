CREATE OR REPLACE FUNCTION cad._render_tree_node(p_shape cad.shape)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_icon text;
  v_props text := '';
  v_label text;
BEGIN
  -- Icon per type
  v_icon := CASE p_shape.type
    WHEN 'line' THEN '&#9473;'
    WHEN 'rect' THEN '&#9635;'
    WHEN 'circle' THEN '&#9675;'
    WHEN 'arc' THEN '&#8978;'
    WHEN 'polyline' THEN '&#10097;'
    WHEN 'text' THEN 'T'
    WHEN 'dimension' THEN '&#8596;'
    ELSE '?'
  END;

  -- Label
  v_label := COALESCE(p_shape.label, p_shape.type || ' #' || p_shape.id);

  -- Wood props if present
  IF p_shape.props->>'section' IS NOT NULL THEN
    v_props := p_shape.props->>'section';
    IF p_shape.props->>'wood_type' IS NOT NULL THEN
      v_props := v_props || ' ' || (p_shape.props->>'wood_type');
    END IF;
  END IF;

  RETURN '<div class="cad-tree-node" data-id="' || p_shape.id || '"'
    || ' @click="select(' || p_shape.id || ')">'
    || '<span class="cad-tree-icon">' || v_icon || '</span>'
    || pgv.esc(v_label)
    || CASE WHEN v_props <> '' 
         THEN '<span class="cad-tree-props">' || pgv.esc(v_props) || '</span>'
         ELSE '' END
    || '</div>';
END;
$function$;
