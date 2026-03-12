CREATE OR REPLACE FUNCTION cad_ut.test_bill_of_materials()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_pid1 int;
  v_pid2 int;
  v_bom text;
BEGIN
  INSERT INTO cad.drawing (name) VALUES ('test_bom') RETURNING id INTO v_did;

  -- Add two beams
  v_pid1 := cad.add_beam(v_did, '60x90', ARRAY[0,0,0]::real[], ARRAY[2000,0,0]::real[], 'S1', 'solive');
  v_pid2 := cad.add_beam(v_did, '60x90', ARRAY[0,500,0]::real[], ARRAY[2000,500,0]::real[], 'S2', 'solive');

  -- BOM without groups
  v_bom := cad.bill_of_materials(v_did);
  RETURN NEXT ok(v_bom IS NOT NULL, 'bom returns text');
  RETURN NEXT ok(v_bom LIKE '%2x 60x90%', 'bom shows 2x 60x90');
  RETURN NEXT ok(v_bom LIKE '%Total: 2 pieces%', 'bom total = 2 pieces');
  RETURN NEXT ok(v_bom LIKE '%solive%', 'bom shows role');

  -- Group pieces and re-check
  PERFORM cad.group_pieces(v_did, ARRAY[v_pid1, v_pid2], 'Plancher');
  v_bom := cad.bill_of_materials(v_did);
  RETURN NEXT ok(v_bom LIKE '%Plancher%', 'bom shows group label');
  RETURN NEXT ok(v_bom LIKE '%Total: 2 pieces%', 'grouped bom total still 2');

  -- Empty drawing
  INSERT INTO cad.drawing (name) VALUES ('test_bom_empty') RETURNING id INTO v_did;
  v_bom := cad.bill_of_materials(v_did);
  RETURN NEXT ok(v_bom LIKE '%Total: 0 pieces%', 'empty drawing = 0 pieces');
END;
$function$;
