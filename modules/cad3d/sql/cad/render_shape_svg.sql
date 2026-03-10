CREATE OR REPLACE FUNCTION cad.render_shape_svg(p_shape cad.shape, p_layer_color text, p_unit text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_g jsonb := p_shape.geometry;
  v_el text := '';
BEGIN
  CASE p_shape.type
    WHEN 'line' THEN
      v_el := format('<line x1="%s" y1="%s" x2="%s" y2="%s"/>',
        v_g->>'x1', v_g->>'y1', v_g->>'x2', v_g->>'y2');
    WHEN 'rect' THEN
      v_el := format('<rect x="%s" y="%s" width="%s" height="%s"%s/>',
        v_g->>'x', v_g->>'y', v_g->>'w', v_g->>'h',
        CASE WHEN v_g->>'rotation' IS NOT NULL
          THEN format(' transform="rotate(%s %s %s)"',
            v_g->>'rotation',
            (v_g->>'x')::real + (v_g->>'w')::real/2,
            (v_g->>'y')::real + (v_g->>'h')::real/2)
          ELSE '' END);
    WHEN 'circle' THEN
      v_el := format('<circle cx="%s" cy="%s" r="%s"/>',
        v_g->>'cx', v_g->>'cy', v_g->>'r');
    WHEN 'arc' THEN
      v_el := cad.render_arc(v_g);
    WHEN 'polyline' THEN
      v_el := format('<polyline points="%s"/>',
        (SELECT string_agg(
          (p->0)::text || ',' || (p->1)::text, ' '
        ) FROM jsonb_array_elements(v_g->'points') AS p));
    WHEN 'text' THEN
      v_el := format('<text x="%s" y="%s" font-size="%s" text-anchor="%s" fill="%s" stroke="none">%s</text>',
        v_g->>'x', v_g->>'y',
        COALESCE(v_g->>'size', '14'),
        COALESCE(v_g->>'anchor', 'start'),
        p_layer_color,
        pgv.esc(v_g->>'content'));
    WHEN 'dimension' THEN
      v_el := cad.render_dimension(v_g, p_unit);
    ELSE
      RETURN '';
  END CASE;

  IF v_el IS NOT NULL AND v_el <> '' THEN
    RETURN format('<g data-shape-id="%s" class="shape"%s>%s</g>',
      p_shape.id,
      CASE WHEN p_shape.label IS NOT NULL
        THEN ' data-label="' || pgv.esc(p_shape.label) || '"'
        ELSE '' END,
      v_el);
  END IF;

  RETURN '';
END;
$function$;
