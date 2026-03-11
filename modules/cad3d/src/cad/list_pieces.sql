CREATE OR REPLACE FUNCTION cad.list_pieces(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rec record;
  v_out text := '';
BEGIN
  FOR v_rec IN
    SELECT p.id, p.label, p.role, p.section, p.length_mm, p.wood_type,
           round(ST_XMin(p.geom)::numeric,1) AS x1, round(ST_YMin(p.geom)::numeric,1) AS y1, round(ST_ZMin(p.geom)::numeric,1) AS z1,
           round(ST_XMax(p.geom)::numeric,1) AS x2, round(ST_YMax(p.geom)::numeric,1) AS y2, round(ST_ZMax(p.geom)::numeric,1) AS z2,
           g.label AS group_label
    FROM cad.piece p
    LEFT JOIN cad.piece_group g ON g.id = p.group_id
    WHERE p.drawing_id = p_drawing_id
    ORDER BY p.group_id NULLS LAST, p.id
  LOOP
    v_out := v_out || '#' || v_rec.id || ' ' || coalesce(v_rec.label, '(unnamed)')
      || ' [' || v_rec.role || '] ' || v_rec.section || ' ' || v_rec.wood_type
      || ' L=' || v_rec.length_mm || 'mm'
      || '  [' || v_rec.x1 || ',' || v_rec.y1 || ',' || v_rec.z1
      || ']->[' || v_rec.x2 || ',' || v_rec.y2 || ',' || v_rec.z2 || ']';
    IF v_rec.group_label IS NOT NULL THEN
      v_out := v_out || '  grp: ' || v_rec.group_label;
    END IF;
    v_out := v_out || E'\n';
  END LOOP;

  IF v_out = '' THEN RETURN 'no pieces in drawing #' || p_drawing_id; END IF;
  RETURN v_out;
END;
$function$;
