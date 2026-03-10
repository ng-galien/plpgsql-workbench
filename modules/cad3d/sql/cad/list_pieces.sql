CREATE OR REPLACE FUNCTION cad.list_pieces(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rec record;
  v_out text := '';
BEGIN
  FOR v_rec IN
    SELECT id, label, role, section, length_mm, wood_type,
           round(ST_XMin(geom)::numeric,1) AS x1, round(ST_YMin(geom)::numeric,1) AS y1, round(ST_ZMin(geom)::numeric,1) AS z1,
           round(ST_XMax(geom)::numeric,1) AS x2, round(ST_YMax(geom)::numeric,1) AS y2, round(ST_ZMax(geom)::numeric,1) AS z2
    FROM cad.piece
    WHERE drawing_id = p_drawing_id
    ORDER BY id
  LOOP
    v_out := v_out || '#' || v_rec.id || ' ' || coalesce(v_rec.label, '(unnamed)')
      || ' [' || v_rec.role || '] ' || v_rec.section || ' ' || v_rec.wood_type
      || ' L=' || v_rec.length_mm || 'mm'
      || '  [' || v_rec.x1 || ',' || v_rec.y1 || ',' || v_rec.z1
      || ']->[' || v_rec.x2 || ',' || v_rec.y2 || ',' || v_rec.z2 || ']'
      || E'\n';
  END LOOP;

  IF v_out = '' THEN RETURN 'no pieces in drawing #' || p_drawing_id; END IF;
  RETURN v_out;
END;
$function$;
