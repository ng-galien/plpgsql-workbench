CREATE OR REPLACE FUNCTION cad._render_tree_group(p_group_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text := '';
  v_group cad.shape;
  v_child cad.shape;
  v_count int;
BEGIN
  SELECT * INTO v_group FROM cad.shape WHERE id = p_group_id;
  IF NOT FOUND THEN RETURN ''; END IF;

  SELECT count(*) INTO v_count FROM cad.shape WHERE parent_id = p_group_id;

  v_html := '<details open>'
    || '<summary @click.stop="selectGroup(' || p_group_id || ')">'
    || '<span class="cad-tree-icon">&#128230;</span>'
    || pgv.esc(COALESCE(v_group.label, 'Groupe #' || p_group_id))
    || ' <span class="cad-tree-props">(' || v_count || ')</span>'
    || '</summary>'
    || '<div>';

  FOR v_child IN
    SELECT * FROM cad.shape WHERE parent_id = p_group_id ORDER BY sort_order, id
  LOOP
    IF v_child.type = 'group' THEN
      v_html := v_html || cad._render_tree_group(v_child.id);
    ELSE
      v_html := v_html || cad._render_tree_node(v_child);
    END IF;
  END LOOP;

  v_html := v_html || '</div></details>';
  RETURN v_html;
END;
$function$;
