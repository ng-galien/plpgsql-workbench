CREATE OR REPLACE FUNCTION cad.render_group_svg(p_group_id integer, p_layer_color text, p_unit text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_shape cad.shape;
  v_svg text := '';
  v_label text;
BEGIN
  -- Label du groupe
  SELECT label INTO v_label FROM cad.shape WHERE id = p_group_id;

  FOR v_shape IN
    SELECT * FROM cad.shape WHERE parent_id = p_group_id ORDER BY sort_order
  LOOP
    IF v_shape.type = 'group' THEN
      v_svg := v_svg || cad.render_group_svg(v_shape.id, p_layer_color, p_unit);
    ELSE
      v_svg := v_svg || cad.render_shape_svg(v_shape, p_layer_color, p_unit);
    END IF;
  END LOOP;

  RETURN format('<g data-group-id="%s" class="group"%s>%s</g>',
    p_group_id,
    CASE WHEN v_label IS NOT NULL
      THEN ' data-label="' || pgv.esc(v_label) || '"'
      ELSE '' END,
    v_svg);
END;
$function$;
