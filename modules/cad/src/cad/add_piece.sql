CREATE OR REPLACE FUNCTION cad.add_piece(p_drawing_id integer, p_section text, p_length_mm real, p_position real[] DEFAULT ARRAY[0, 0, 0], p_rotation real[] DEFAULT ARRAY[0, 0, 0], p_label text DEFAULT NULL::text, p_role text DEFAULT NULL::text, p_wood_type text DEFAULT 'pin'::text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_w real;
  v_h real;
  v_profile geometry;
  v_solid geometry;
  v_parts text[];
BEGIN
  -- Parse section "60x90" -> w=60, h=90
  v_parts := string_to_array(p_section, 'x');
  IF array_length(v_parts, 1) <> 2 THEN
    RAISE EXCEPTION 'section must be WxH (e.g. 60x90), got: %', p_section;
  END IF;
  v_w := v_parts[1]::real;
  v_h := v_parts[2]::real;

  -- Profil 2D (rectangle en Z=0)
  v_profile := ST_MakePolygon(ST_MakeLine(ARRAY[
    ST_MakePoint(0, 0, 0),
    ST_MakePoint(v_w, 0, 0),
    ST_MakePoint(v_w, v_h, 0),
    ST_MakePoint(0, v_h, 0),
    ST_MakePoint(0, 0, 0)
  ]));

  -- Extrusion le long de Z
  v_solid := ST_Extrude(v_profile, 0, 0, p_length_mm);

  -- Rotation (rz, ry, rx en degrés)
  IF p_rotation[3] <> 0 THEN
    v_solid := ST_RotateX(v_solid, radians(p_rotation[3]));
    v_profile := ST_RotateX(v_profile, radians(p_rotation[3]));
  END IF;
  IF p_rotation[2] <> 0 THEN
    v_solid := ST_RotateY(v_solid, radians(p_rotation[2]));
    v_profile := ST_RotateY(v_profile, radians(p_rotation[2]));
  END IF;
  IF p_rotation[1] <> 0 THEN
    v_solid := ST_RotateZ(v_solid, radians(p_rotation[1]));
    v_profile := ST_RotateZ(v_profile, radians(p_rotation[1]));
  END IF;

  -- Translation
  IF p_position[1] <> 0 OR p_position[2] <> 0 OR p_position[3] <> 0 THEN
    v_solid := ST_Translate(v_solid, p_position[1], p_position[2], p_position[3]);
    v_profile := ST_Translate(v_profile, p_position[1], p_position[2], p_position[3]);
  END IF;

  INSERT INTO cad.piece (drawing_id, label, role, wood_type, section, length_mm, profile, geom)
  VALUES (p_drawing_id, p_label, p_role, p_wood_type, p_section, p_length_mm, v_profile, v_solid)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;
