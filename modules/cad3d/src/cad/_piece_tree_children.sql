CREATE OR REPLACE FUNCTION cad._piece_tree_children(p_drawing_id integer, p_parent_group_id integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_items jsonb := '[]'::jsonb;
  v_grp record;
  v_piece record;
  v_color text;
  v_node jsonb;
BEGIN
  -- Sub-groups
  FOR v_grp IN
    SELECT g.id, g.label,
      (SELECT count(*) FROM cad.piece p WHERE p.group_id = g.id) AS piece_count
    FROM cad.piece_group g
    WHERE g.drawing_id = p_drawing_id
      AND ((p_parent_group_id IS NULL AND g.parent_id IS NULL)
           OR g.parent_id = p_parent_group_id)
    ORDER BY g.label
  LOOP
    v_node := jsonb_build_object(
      'label', v_grp.label,
      'icon', '&#128230;',
      'badge', '(' || v_grp.piece_count || ')',
      'action', '<button class="cad-tree-eye" @click.stop="toggleGroup(' || v_grp.id || ')">&#9673;</button>',
      'attrs', 'data-group="' || v_grp.id || '"',
      'open', true,
      'children', cad._piece_tree_children(p_drawing_id, v_grp.id)
    );
    v_items := v_items || jsonb_build_array(v_node);
  END LOOP;

  -- Pieces in this group (or ungrouped at root)
  FOR v_piece IN
    SELECT p.id, p.label, p.role, p.section, p.wood_type
    FROM cad.piece p
    WHERE p.drawing_id = p_drawing_id
      AND ((p_parent_group_id IS NULL AND p.group_id IS NULL)
           OR p.group_id = p_parent_group_id)
    ORDER BY p.role, p.label, p.id
  LOOP
    v_color := CASE v_piece.role
      WHEN 'poteau' THEN '#c8956c' WHEN 'traverse' THEN '#a07850'
      WHEN 'chevron' THEN '#d4a76a' WHEN 'lisse' THEN '#b8925a'
      WHEN 'montant' THEN '#c8956c' ELSE '#c8a882'
    END;

    v_node := jsonb_build_object(
      'label', COALESCE(v_piece.label, '#' || v_piece.id),
      'icon', '<span class="cad-tree-swatch" data-color="' || v_color || '"></span>',
      'badge', v_piece.section || ' ' || v_piece.wood_type,
      'action', '<button class="cad-tree-eye" @click.stop="togglePiece(' || v_piece.id || ')">&#9673;</button>',
      'attrs', 'data-piece-id="' || v_piece.id || '" @click="selectPiece(' || v_piece.id || ')"'
    );
    v_items := v_items || jsonb_build_array(v_node);
  END LOOP;

  RETURN v_items;
END;
$function$;
