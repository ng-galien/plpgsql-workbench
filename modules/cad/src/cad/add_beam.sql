CREATE OR REPLACE FUNCTION cad.add_beam(p_drawing_id integer, p_section text, p_start real[], p_end real[], p_label text DEFAULT NULL::text, p_role text DEFAULT NULL::text, p_wood_type text DEFAULT 'pin'::text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_w real;
  v_h real;
  v_parts text[];
  v_dx real; v_dy real; v_dz real;
  v_length real;
  v_profile geometry;
  v_solid geometry;
BEGIN
  v_parts := string_to_array(p_section, 'x');
  v_w := v_parts[1]::real;
  v_h := v_parts[2]::real;

  v_dx := p_end[1] - p_start[1];
  v_dy := p_end[2] - p_start[2];
  v_dz := p_end[3] - p_start[3];
  v_length := sqrt(v_dx*v_dx + v_dy*v_dy + v_dz*v_dz);

  IF v_length < 1 THEN
    RAISE EXCEPTION 'beam length must be > 0, got start=% end=%', p_start, p_end;
  END IF;

  -- Profile perpendicular to dominant axis, extrusion along FULL vector
  IF abs(v_dx) >= abs(v_dy) AND abs(v_dx) >= abs(v_dz) THEN
    -- X-dominant: profile in YZ plane
    v_profile := ST_MakePolygon(ST_MakeLine(ARRAY[
      ST_MakePoint(p_start[1], p_start[2], p_start[3]),
      ST_MakePoint(p_start[1], p_start[2] + v_w, p_start[3]),
      ST_MakePoint(p_start[1], p_start[2] + v_w, p_start[3] + v_h),
      ST_MakePoint(p_start[1], p_start[2], p_start[3] + v_h),
      ST_MakePoint(p_start[1], p_start[2], p_start[3])
    ]));
  ELSIF abs(v_dy) >= abs(v_dx) AND abs(v_dy) >= abs(v_dz) THEN
    -- Y-dominant: profile in XZ plane
    v_profile := ST_MakePolygon(ST_MakeLine(ARRAY[
      ST_MakePoint(p_start[1], p_start[2], p_start[3]),
      ST_MakePoint(p_start[1] + v_w, p_start[2], p_start[3]),
      ST_MakePoint(p_start[1] + v_w, p_start[2], p_start[3] + v_h),
      ST_MakePoint(p_start[1], p_start[2], p_start[3] + v_h),
      ST_MakePoint(p_start[1], p_start[2], p_start[3])
    ]));
  ELSE
    -- Z-dominant: profile in XY plane
    v_profile := ST_MakePolygon(ST_MakeLine(ARRAY[
      ST_MakePoint(p_start[1], p_start[2], p_start[3]),
      ST_MakePoint(p_start[1] + v_w, p_start[2], p_start[3]),
      ST_MakePoint(p_start[1] + v_w, p_start[2] + v_h, p_start[3]),
      ST_MakePoint(p_start[1], p_start[2] + v_h, p_start[3]),
      ST_MakePoint(p_start[1], p_start[2], p_start[3])
    ]));
  END IF;

  -- Extrude along FULL direction vector (supports diagonals)
  v_solid := ST_Extrude(v_profile, v_dx, v_dy, v_dz);

  INSERT INTO cad.piece (drawing_id, label, role, wood_type, section, length_mm, profile, geom)
  VALUES (p_drawing_id, p_label, p_role, p_wood_type, p_section, v_length, v_profile, v_solid)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;
