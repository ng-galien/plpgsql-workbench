CREATE OR REPLACE FUNCTION cad.snap_piece(p_piece_id integer, p_target_id integer, p_face text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_src cad.piece;
  v_tgt cad.piece;
  v_dx float := 0; v_dy float := 0; v_dz float := 0;
BEGIN
  SELECT * INTO v_src FROM cad.piece WHERE id = p_piece_id;
  IF NOT FOUND THEN RETURN 'error: piece #' || p_piece_id || ' not found'; END IF;
  SELECT * INTO v_tgt FROM cad.piece WHERE id = p_target_id;
  IF NOT FOUND THEN RETURN 'error: piece #' || p_target_id || ' not found'; END IF;

  -- Calculate translation to snap src against target's face
  CASE p_face
    WHEN 'top' THEN
      v_dz := ST_ZMax(v_tgt.geom) - ST_ZMin(v_src.geom);
    WHEN 'bottom' THEN
      v_dz := ST_ZMin(v_tgt.geom) - ST_ZMax(v_src.geom);
    WHEN 'right' THEN
      v_dx := ST_XMax(v_tgt.geom) - ST_XMin(v_src.geom);
    WHEN 'left' THEN
      v_dx := ST_XMin(v_tgt.geom) - ST_XMax(v_src.geom);
    WHEN 'back' THEN
      v_dy := ST_YMax(v_tgt.geom) - ST_YMin(v_src.geom);
    WHEN 'front' THEN
      v_dy := ST_YMin(v_tgt.geom) - ST_YMax(v_src.geom);
    ELSE
      RETURN 'error: invalid face "' || p_face || '". Use: top, bottom, left, right, front, back';
  END CASE;

  UPDATE cad.piece SET
    profile = ST_Translate(profile, v_dx, v_dy, v_dz),
    geom = ST_Translate(geom, v_dx, v_dy, v_dz)
  WHERE id = p_piece_id;

  RETURN 'snapped: ' || coalesce(v_src.label, '#' || p_piece_id)
    || ' -> ' || p_face || ' of ' || coalesce(v_tgt.label, '#' || p_target_id)
    || E'\nmoved: [' || round(v_dx::numeric,1) || ', ' || round(v_dy::numeric,1) || ', ' || round(v_dz::numeric,1) || ']'
    || E'\n' || cad.measure(p_piece_id, p_target_id);
END;
$function$;
