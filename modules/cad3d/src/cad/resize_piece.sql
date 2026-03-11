CREATE OR REPLACE FUNCTION cad.resize_piece(p_piece_id integer, p_new_length_mm double precision)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_p cad.piece;
  v_dx float; v_dy float; v_dz float;
  v_start real[]; v_end real[];
  v_old_length float;
  v_new_id int;
BEGIN
  SELECT * INTO v_p FROM cad.piece WHERE id = p_piece_id;
  IF NOT FOUND THEN RETURN 'error: piece #' || p_piece_id || ' not found'; END IF;

  v_old_length := v_p.length_mm;

  -- Determine the dominant axis by bounding box
  v_dx := ST_XMax(v_p.geom) - ST_XMin(v_p.geom);
  v_dy := ST_YMax(v_p.geom) - ST_YMin(v_p.geom);
  v_dz := ST_ZMax(v_p.geom) - ST_ZMin(v_p.geom);

  -- Rebuild start/end with new length, keeping origin
  IF v_dz > v_dx AND v_dz > v_dy THEN
    v_start := ARRAY[ST_XMin(v_p.geom), ST_YMin(v_p.geom), ST_ZMin(v_p.geom)]::real[];
    v_end := ARRAY[ST_XMin(v_p.geom), ST_YMin(v_p.geom), ST_ZMin(v_p.geom) + p_new_length_mm]::real[];
  ELSIF v_dx > v_dy THEN
    v_start := ARRAY[ST_XMin(v_p.geom), ST_YMin(v_p.geom), ST_ZMin(v_p.geom)]::real[];
    v_end := ARRAY[ST_XMin(v_p.geom) + p_new_length_mm, ST_YMin(v_p.geom), ST_ZMin(v_p.geom)]::real[];
  ELSE
    v_start := ARRAY[ST_XMin(v_p.geom), ST_YMin(v_p.geom), ST_ZMin(v_p.geom)]::real[];
    v_end := ARRAY[ST_XMin(v_p.geom), ST_YMin(v_p.geom) + p_new_length_mm, ST_ZMin(v_p.geom)]::real[];
  END IF;

  -- Create new piece via add_beam
  v_new_id := cad.add_beam(
    v_p.drawing_id, v_p.section,
    v_start, v_end,
    v_p.label, v_p.role, v_p.wood_type
  );

  -- Restaurer le group_id sur la nouvelle pièce
  IF v_p.group_id IS NOT NULL THEN
    UPDATE cad.piece SET group_id = v_p.group_id WHERE id = v_new_id;
  END IF;

  -- Remove old piece
  DELETE FROM cad.piece WHERE id = p_piece_id;

  RETURN 'resized: ' || coalesce(v_p.label, '#' || p_piece_id)
    || ' ' || v_old_length || 'mm -> ' || p_new_length_mm || 'mm'
    || E'\n' || cad.inspect(v_p.drawing_id);
END;
$function$;
