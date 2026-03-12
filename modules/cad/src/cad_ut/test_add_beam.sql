CREATE OR REPLACE FUNCTION cad_ut.test_add_beam()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_pid int;
  v_rec record;
BEGIN
  INSERT INTO cad.drawing (name) VALUES ('test_beam') RETURNING id INTO v_did;

  -- Horizontal beam along X axis
  v_pid := cad.add_beam(v_did, '60x90', ARRAY[0,0,0]::real[], ARRAY[2000,0,0]::real[], 'poutre1', 'solive');
  RETURN NEXT ok(v_pid IS NOT NULL, 'add_beam returns an id');

  SELECT * INTO v_rec FROM cad.piece WHERE id = v_pid;
  RETURN NEXT is(v_rec.section, '60x90', 'section stored');
  RETURN NEXT is(v_rec.wood_type, 'pin', 'default wood_type is pin');
  RETURN NEXT is(v_rec.label, 'poutre1', 'label stored');
  RETURN NEXT is(v_rec.role, 'solive', 'role stored');
  RETURN NEXT ok(v_rec.length_mm = 2000, 'length computed from start/end');
  RETURN NEXT ok(v_rec.geom IS NOT NULL, 'geom generated');
  RETURN NEXT ok(v_rec.profile IS NOT NULL, 'profile generated');
  RETURN NEXT ok(ST_Volume(v_rec.geom) > 0, 'solid has volume');

  -- Diagonal beam
  v_pid := cad.add_beam(v_did, '45x45', ARRAY[0,0,0]::real[], ARRAY[1000,1000,0]::real[]);
  SELECT length_mm INTO v_rec FROM cad.piece WHERE id = v_pid;
  RETURN NEXT ok(abs(v_rec.length_mm - 1414.2) < 1, 'diagonal length ~1414mm');

  -- Error: zero-length beam
  BEGIN
    PERFORM cad.add_beam(v_did, '60x90', ARRAY[0,0,0]::real[], ARRAY[0,0,0]::real[]);
    RETURN NEXT fail('should raise on zero-length beam');
  EXCEPTION WHEN OTHERS THEN
    RETURN NEXT pass('zero-length beam raises exception');
  END;
END;
$function$;
