CREATE OR REPLACE FUNCTION cad_ut.test__piece_tree_children()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_drawing_id int;
  v_p1 int;
  v_p2 int;
  v_p3 int;
  v_html text;
BEGIN
  INSERT INTO cad.drawing (name, scale, unit, width, height)
  VALUES ('Test Children', 1, 'mm', 1000, 1000) RETURNING id INTO v_drawing_id;

  -- Ungrouped pieces — use named params to avoid label/role swap
  v_p1 := cad.add_piece(v_drawing_id, '90x90', 2000, ARRAY[0,0,0]::real[], ARRAY[0,0,0]::real[], p_role := 'poteau', p_label := 'P1');
  v_p2 := cad.add_piece(v_drawing_id, '45x90', 1500, ARRAY[500,0,0]::real[], ARRAY[0,0,0]::real[], p_role := 'traverse', p_label := 'T1');

  v_html := cad.fragment_piece_tree(v_drawing_id);
  RETURN NEXT ok(v_html LIKE '%P1%', 'ungrouped piece P1 rendered');
  RETURN NEXT ok(v_html LIKE '%T1%', 'ungrouped piece T1 rendered');
  RETURN NEXT ok(v_html LIKE '%90x90 pin%', 'badge with section+wood');

  -- Group pieces
  v_p3 := cad.add_piece(v_drawing_id, '45x120', 2200, ARRAY[0,0,2090]::real[], ARRAY[0,90,0]::real[], p_role := 'chevron', p_label := 'C1');
  PERFORM cad.group_pieces(v_drawing_id, ARRAY[v_p1, v_p2], 'Frame');

  v_html := cad.fragment_piece_tree(v_drawing_id);
  RETURN NEXT ok(v_html LIKE '%Frame%', 'group label rendered');
  RETURN NEXT ok(v_html LIKE '%toggleGroup(%', 'group toggle rendered');
  RETURN NEXT ok(v_html LIKE '%C1%', 'ungrouped piece C1 still rendered');

  DELETE FROM cad.drawing WHERE id = v_drawing_id;
END;
$function$;
