CREATE OR REPLACE FUNCTION cad.faces(p_piece_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_p cad.piece;
  v_xmin float; v_ymin float; v_zmin float;
  v_xmax float; v_ymax float; v_zmax float;
BEGIN
  SELECT * INTO v_p FROM cad.piece WHERE id = p_piece_id;
  IF NOT FOUND THEN RETURN 'error: piece #' || p_piece_id || ' not found'; END IF;

  v_xmin := ST_XMin(v_p.geom); v_ymin := ST_YMin(v_p.geom); v_zmin := ST_ZMin(v_p.geom);
  v_xmax := ST_XMax(v_p.geom); v_ymax := ST_YMax(v_p.geom); v_zmax := ST_ZMax(v_p.geom);

  RETURN coalesce(v_p.label, '#' || p_piece_id) || ' faces:'
    || E'\n  top:    z=' || round(v_zmax::numeric, 1)
    || E'\n  bottom: z=' || round(v_zmin::numeric, 1)
    || E'\n  left:   x=' || round(v_xmin::numeric, 1)
    || E'\n  right:  x=' || round(v_xmax::numeric, 1)
    || E'\n  front:  y=' || round(v_ymin::numeric, 1)
    || E'\n  back:   y=' || round(v_ymax::numeric, 1)
    || E'\n  size:   ' || round((v_xmax - v_xmin)::numeric, 1) || ' x '
                       || round((v_ymax - v_ymin)::numeric, 1) || ' x '
                       || round((v_zmax - v_zmin)::numeric, 1) || ' mm';
END;
$function$;
