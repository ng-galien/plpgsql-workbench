CREATE OR REPLACE FUNCTION cad_ut.test_fragment_piece_tree()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_drawing_id int;
  v_p1 int;
  v_p2 int;
  v_p3 int;
  v_grp_id int;
  v_html text;
BEGIN
  -- Setup: create drawing + pieces
  INSERT INTO cad.drawing (name, scale, unit, width, height)
  VALUES ('Test Tree', 1, 'mm', 1000, 1000) RETURNING id INTO v_drawing_id;

  v_p1 := cad.add_piece(v_drawing_id, '90x90', 2000, ARRAY[0,0,0]::real[], ARRAY[0,0,0]::real[], 'poteau', 'Poteau 1');
  v_p2 := cad.add_piece(v_drawing_id, '45x90', 1500, ARRAY[0,0,2000]::real[], ARRAY[0,0,0]::real[], 'traverse', 'Traverse 1');
  v_p3 := cad.add_piece(v_drawing_id, '45x120', 2200, ARRAY[0,0,2090]::real[], ARRAY[0,90,0]::real[], 'chevron', 'Chevron 1');

  -- Test ungrouped pieces
  v_html := cad.fragment_piece_tree(v_drawing_id);
  RETURN NEXT ok(v_html LIKE '%cadPieceTree%', 'root has cadPieceTree x-data');
  RETURN NEXT ok(v_html LIKE '%pgv-tree%', 'uses pgv-tree');
  RETURN NEXT ok(v_html LIKE '%data-piece-id="' || v_p1 || '"%', 'piece 1 in tree');
  RETURN NEXT ok(v_html LIKE '%data-piece-id="' || v_p2 || '"%', 'piece 2 in tree');
  RETURN NEXT ok(v_html LIKE '%data-piece-id="' || v_p3 || '"%', 'piece 3 in tree');
  RETURN NEXT ok(v_html LIKE '%cad-tree-swatch%', 'has color swatches');
  RETURN NEXT ok(v_html LIKE '%cad-tree-eye%', 'has eye toggles');
  RETURN NEXT ok(v_html LIKE '%selectPiece(%', 'has selectPiece handlers');

  -- Group two pieces
  SELECT cad.group_pieces(v_drawing_id, ARRAY[v_p1, v_p2], 'Structure') INTO v_grp_id;
  v_html := cad.fragment_piece_tree(v_drawing_id);
  RETURN NEXT ok(v_html LIKE '%data-group="' || v_grp_id || '"%', 'group node in tree');
  RETURN NEXT ok(v_html LIKE '%Structure%', 'group label visible');
  RETURN NEXT ok(v_html LIKE '%toggleGroup(%', 'has toggleGroup handler');

  -- Cleanup
  DELETE FROM cad.drawing WHERE id = v_drawing_id;
END;
$function$;
