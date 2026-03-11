CREATE OR REPLACE FUNCTION cad.list_groups(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rec record;
  v_out text := '';
  v_indent text;
BEGIN
  -- CTE récursive pour hiérarchie avec profondeur
  FOR v_rec IN
    WITH RECURSIVE tree AS (
      SELECT g.id, g.label, g.parent_id, 0 AS depth
      FROM cad.piece_group g
      WHERE g.drawing_id = p_drawing_id AND g.parent_id IS NULL
      UNION ALL
      SELECT g.id, g.label, g.parent_id, t.depth + 1
      FROM cad.piece_group g
      JOIN tree t ON t.id = g.parent_id
    )
    SELECT t.id, t.label, t.depth,
      (SELECT count(*) FROM cad.piece p WHERE p.group_id = t.id) AS piece_count,
      (SELECT round((sum(ST_Volume(p.geom)) / 1e9)::numeric, 4)
       FROM cad.piece p WHERE p.group_id = t.id) AS vol_m3,
      (SELECT format('[%s,%s,%s]->[%s,%s,%s]',
        round(min(ST_XMin(p.geom))::numeric), round(min(ST_YMin(p.geom))::numeric), round(min(ST_ZMin(p.geom))::numeric),
        round(max(ST_XMax(p.geom))::numeric), round(max(ST_YMax(p.geom))::numeric), round(max(ST_ZMax(p.geom))::numeric))
       FROM cad.piece p WHERE p.group_id = t.id
       HAVING count(*) > 0) AS bbox
    FROM tree t
    ORDER BY t.depth, t.label
  LOOP
    v_indent := repeat('  ', v_rec.depth);
    v_out := v_out || v_indent
      || format('#%s %s (%s pieces', v_rec.id, v_rec.label, v_rec.piece_count);
    IF v_rec.vol_m3 IS NOT NULL THEN
      v_out := v_out || format(', %s m3', v_rec.vol_m3);
    END IF;
    v_out := v_out || ')';
    IF v_rec.bbox IS NOT NULL THEN
      v_out := v_out || '  ' || v_rec.bbox;
    END IF;
    v_out := v_out || E'\n';
  END LOOP;

  IF v_out = '' THEN RETURN 'no groups in drawing #' || p_drawing_id; END IF;
  RETURN v_out;
END;
$function$;
