CREATE OR REPLACE FUNCTION cad_ut.test_scene_json()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_pid int;
  v_json jsonb;
  v_piece jsonb;
BEGIN
  INSERT INTO cad.drawing (name) VALUES ('test_scene') RETURNING id INTO v_did;

  -- Empty drawing
  v_json := cad.scene_json(v_did);
  RETURN NEXT ok(v_json IS NOT NULL, 'scene_json returns jsonb');
  RETURN NEXT is((v_json->'pieces')::text, '[]'::text, 'empty drawing has empty pieces');
  RETURN NEXT is((v_json->'groups')::text, '[]'::text, 'empty drawing has empty groups');

  -- Add a beam
  v_pid := cad.add_beam(v_did, '60x90', ARRAY[0,0,0]::real[], ARRAY[1000,0,0]::real[], 'P1', 'montant', 'chene');
  v_json := cad.scene_json(v_did);
  RETURN NEXT is(jsonb_array_length(v_json->'pieces'), 1, 'one piece in scene');

  v_piece := v_json->'pieces'->0;
  RETURN NEXT is((v_piece->>'label'), 'P1', 'piece label');
  RETURN NEXT is((v_piece->>'role'), 'montant', 'piece role');
  RETURN NEXT is((v_piece->>'wood_type'), 'chene', 'piece wood_type');
  RETURN NEXT is((v_piece->>'section'), '60x90', 'piece section');
  RETURN NEXT ok(v_piece->'mesh' IS NOT NULL, 'piece has mesh');
  RETURN NEXT ok((v_piece->'mesh'->>'type') = 'GeometryCollection', 'mesh is GeometryCollection');

  -- Add group
  PERFORM cad.group_pieces(v_did, ARRAY[v_pid], 'Mur1');
  v_json := cad.scene_json(v_did);
  RETURN NEXT is(jsonb_array_length(v_json->'groups'), 1, 'one group in scene');
  RETURN NEXT is((v_json->'groups'->0->>'label'), 'Mur1', 'group label');
  RETURN NEXT is((v_json->'pieces'->0->>'group_label'), 'Mur1', 'piece has group_label');
END;
$function$;
