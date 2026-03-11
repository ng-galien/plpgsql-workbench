CREATE OR REPLACE FUNCTION cad.duplicate_piece(p_piece_id integer, p_dx double precision DEFAULT 0, p_dy double precision DEFAULT 0, p_dz double precision DEFAULT 0, p_label text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_src cad.piece;
  v_new_id int;
BEGIN
  SELECT * INTO v_src FROM cad.piece WHERE id = p_piece_id;
  IF NOT FOUND THEN RETURN 'error: piece #' || p_piece_id || ' not found'; END IF;

  INSERT INTO cad.piece (drawing_id, label, role, wood_type, section, length_mm, profile, geom, group_id)
  VALUES (
    v_src.drawing_id,
    coalesce(p_label, v_src.label || ' (copy)'),
    v_src.role,
    v_src.wood_type,
    v_src.section,
    v_src.length_mm,
    ST_Translate(v_src.profile, p_dx, p_dy, p_dz),
    ST_Translate(v_src.geom, p_dx, p_dy, p_dz),
    v_src.group_id
  )
  RETURNING id INTO v_new_id;

  RETURN 'duplicated: #' || p_piece_id || ' -> #' || v_new_id
    || ' ' || coalesce(p_label, v_src.label || ' (copy)')
    || E'\noffset: [' || p_dx || ', ' || p_dy || ', ' || p_dz || ']'
    || E'\n' || cad.inspect(v_src.drawing_id);
END;
$function$;
