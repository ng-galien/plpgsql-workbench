CREATE OR REPLACE FUNCTION cad.neighbors(p_piece_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_piece cad.piece;
  v_out text;
  v_rec record;
BEGIN
  SELECT * INTO v_piece FROM cad.piece WHERE id = p_piece_id;
  IF NOT FOUND THEN RETURN 'piece not found'; END IF;

  v_out := format('%s [%s] %s %smm', v_piece.label, v_piece.role, v_piece.section, v_piece.length_mm::int);
  v_out := v_out || format('  pos:[%s,%s,%s]->[%s,%s,%s]',
    round(ST_XMin(v_piece.geom)::numeric), round(ST_YMin(v_piece.geom)::numeric), round(ST_ZMin(v_piece.geom)::numeric),
    round(ST_XMax(v_piece.geom)::numeric), round(ST_YMax(v_piece.geom)::numeric), round(ST_ZMax(v_piece.geom)::numeric)
  ) || E'\n\n';

  v_out := v_out || 'connected to:' || E'\n';
  FOR v_rec IN
    SELECT o.id, o.label, o.role,
      round(ST_3DDistance(v_piece.geom, o.geom)::numeric, 1) AS dist,
      CASE
        WHEN ST_ZMax(o.geom) <= ST_ZMin(v_piece.geom) + 1 THEN 'below'
        WHEN ST_ZMin(o.geom) >= ST_ZMax(v_piece.geom) - 1 THEN 'above'
        WHEN ST_XMax(o.geom) <= ST_XMin(v_piece.geom) + 1 THEN 'left'
        WHEN ST_XMin(o.geom) >= ST_XMax(v_piece.geom) - 1 THEN 'right'
        ELSE 'side'
      END AS direction
    FROM cad.piece o
    WHERE o.drawing_id = v_piece.drawing_id AND o.id <> v_piece.id
      AND ST_3DIntersects(v_piece.geom, o.geom)
    ORDER BY o.id
  LOOP
    v_out := v_out || format('  %s [%s] -> %s', v_rec.label, v_rec.role, v_rec.direction) || E'\n';
  END LOOP;

  -- Nearest non-connected pieces
  v_out := v_out || E'\n' || 'nearest unconnected:' || E'\n';
  FOR v_rec IN
    SELECT o.id, o.label, o.role,
      round(ST_3DDistance(v_piece.geom, o.geom)::numeric, 1) AS dist
    FROM cad.piece o
    WHERE o.drawing_id = v_piece.drawing_id AND o.id <> v_piece.id
      AND NOT ST_3DIntersects(v_piece.geom, o.geom)
    ORDER BY ST_3DDistance(v_piece.geom, o.geom)
    LIMIT 3
  LOOP
    v_out := v_out || format('  %s [%s] at %smm', v_rec.label, v_rec.role, v_rec.dist) || E'\n';
  END LOOP;

  RETURN v_out;
END;
$function$;
