CREATE OR REPLACE FUNCTION cad.fragment_tree(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_html text := '';
  v_layer record;
  v_shape cad.shape;
BEGIN
  v_html := '<div x-data="cadTree" class="cad-tree">';

  FOR v_layer IN
    SELECT * FROM cad.layer
    WHERE drawing_id = p_drawing_id
    ORDER BY sort_order, id
  LOOP
    v_html := v_html || '<details open>'
      || '<summary>'
      || '<span class="cad-tree-swatch" data-color="' || pgv.esc(v_layer.color) || '"></span>'
      || pgv.esc(v_layer.name)
      || ' <span class="cad-tree-props">(' || (
           SELECT count(*) FROM cad.shape WHERE layer_id = v_layer.id AND type <> 'group'
         )::text || ')</span>'
      || '<button class="cad-tree-eye" data-layer="' || v_layer.id || '"'
      || ' @click.stop="toggleLayer(' || v_layer.id || ')">'
      || CASE WHEN v_layer.visible THEN E'\u25C9' ELSE E'\u25CB' END
      || '</button>'
      || '</summary>'
      || '<div>';

    FOR v_shape IN
      SELECT * FROM cad.shape
      WHERE layer_id = v_layer.id AND type <> 'group'
      ORDER BY sort_order, id
    LOOP
      v_html := v_html || cad._render_tree_node(v_shape);
    END LOOP;

    v_html := v_html || '</div></details>';
  END LOOP;

  v_html := v_html || '</div>';
  RETURN v_html;
END;
$function$;
