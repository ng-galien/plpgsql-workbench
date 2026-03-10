CREATE OR REPLACE FUNCTION cad.cross_section(p_drawing_id integer, p_axis text, p_value double precision)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rec record;
  v_out text := 'Cross section at ' || p_axis || '=' || p_value || 'mm' || E'\n';
  v_count int := 0;
BEGIN
  FOR v_rec IN
    SELECT id, label, role, section,
           round(ST_XMin(geom)::numeric,1) AS x1, round(ST_YMin(geom)::numeric,1) AS y1, round(ST_ZMin(geom)::numeric,1) AS z1,
           round(ST_XMax(geom)::numeric,1) AS x2, round(ST_YMax(geom)::numeric,1) AS y2, round(ST_ZMax(geom)::numeric,1) AS z2
    FROM cad.piece
    WHERE drawing_id = p_drawing_id
      AND CASE p_axis
            WHEN 'x' THEN ST_XMin(geom) <= p_value AND ST_XMax(geom) >= p_value
            WHEN 'y' THEN ST_YMin(geom) <= p_value AND ST_YMax(geom) >= p_value
            WHEN 'z' THEN ST_ZMin(geom) <= p_value AND ST_ZMax(geom) >= p_value
          END
    ORDER BY id
  LOOP
    v_count := v_count + 1;
    v_out := v_out || '  #' || v_rec.id || ' ' || coalesce(v_rec.label, '') || ' [' || v_rec.role || '] ' || v_rec.section
      || '  bbox:[' || v_rec.x1 || ',' || v_rec.y1 || ',' || v_rec.z1
      || ']->[' || v_rec.x2 || ',' || v_rec.y2 || ',' || v_rec.z2 || ']'
      || E'\n';
  END LOOP;

  v_out := v_out || v_count || ' pieces intersected';
  RETURN v_out;
END;
$function$;
