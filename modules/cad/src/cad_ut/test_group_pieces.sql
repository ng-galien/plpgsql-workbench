CREATE OR REPLACE FUNCTION cad_ut.test_group_pieces()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_p1 int; v_p2 int; v_p3 int; v_p4 int;
  v_gid int; v_gid2 int;
  v_count int;
  v_z_before real; v_z_after real;
BEGIN
  -- Setup: dessin + 4 pièces
  INSERT INTO cad.drawing (name) VALUES ('test_groups') RETURNING id INTO v_did;
  v_p1 := cad.add_piece(v_did, '60x60', 2000, ARRAY[0,0,0]::real[], ARRAY[0,0,0]::real[], 'P1', 'poteau');
  v_p2 := cad.add_piece(v_did, '60x60', 2000, ARRAY[1000,0,0]::real[], ARRAY[0,0,0]::real[], 'P2', 'poteau');
  v_p3 := cad.add_piece(v_did, '45x90', 1060, ARRAY[0,0,2000]::real[], ARRAY[0,90,0]::real[], 'T1', 'traverse');
  v_p4 := cad.add_piece(v_did, '45x90', 1060, ARRAY[0,0,2500]::real[], ARRAY[0,90,0]::real[], 'T2', 'traverse');

  -- Test 1: group_pieces
  v_gid := cad.group_pieces(v_did, ARRAY[v_p1, v_p2], 'Poteaux');
  RETURN NEXT ok(v_gid IS NOT NULL, 'group_pieces returns group_id');
  SELECT count(*) INTO v_count FROM cad.piece WHERE group_id = v_gid;
  RETURN NEXT is(v_count, 2, 'group has 2 pieces');

  -- Test 2: rename_group
  PERFORM cad.rename_group(v_gid, 'Poteaux Mur Nord');
  RETURN NEXT is(
    (SELECT label FROM cad.piece_group WHERE id = v_gid),
    'Poteaux Mur Nord', 'rename_group works'
  );

  -- Test 3: list_groups
  RETURN NEXT ok(
    cad.list_groups(v_did) LIKE '%Poteaux Mur Nord%',
    'list_groups shows group'
  );

  -- Test 4: move_group_pieces
  SELECT ST_ZMin(geom) INTO v_z_before FROM cad.piece WHERE id = v_p1;
  PERFORM cad.move_group_pieces(v_gid, 0, 0, 500);
  SELECT ST_ZMin(geom) INTO v_z_after FROM cad.piece WHERE id = v_p1;
  RETURN NEXT ok(abs(v_z_after - v_z_before - 500) < 1, 'move_group_pieces translates pieces');

  -- Test 5: duplicate_group
  v_gid2 := cad.duplicate_group(v_gid, 0, 2000, 0);
  RETURN NEXT ok(v_gid2 IS NOT NULL AND v_gid2 <> v_gid, 'duplicate_group creates new group');
  SELECT count(*) INTO v_count FROM cad.piece WHERE group_id = v_gid2;
  RETURN NEXT is(v_count, 2, 'duplicated group has 2 pieces');

  -- Test 6: nest_group
  PERFORM cad.nest_group(v_gid2, v_gid);
  RETURN NEXT is(
    (SELECT parent_id FROM cad.piece_group WHERE id = v_gid2),
    v_gid, 'nest_group sets parent_id'
  );

  -- Test 7: ungroup_pieces
  v_count := cad.ungroup_pieces(v_gid2);
  RETURN NEXT is(v_count, 2, 'ungroup_pieces detaches pieces');
  RETURN NEXT ok(
    NOT EXISTS (SELECT 1 FROM cad.piece_group WHERE id = v_gid2),
    'ungroup_pieces deletes group'
  );

  -- Test 8: remove_group with pieces
  v_gid2 := cad.group_pieces(v_did, ARRAY[v_p3, v_p4], 'Traverses');
  PERFORM cad.remove_group(v_gid2, false);
  RETURN NEXT ok(
    NOT EXISTS (SELECT 1 FROM cad.piece WHERE id IN (v_p3, v_p4)),
    'remove_group(keep:=false) deletes pieces'
  );

  -- Cleanup
  DELETE FROM cad.drawing WHERE id = v_did;
END;
$function$;
