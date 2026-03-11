CREATE OR REPLACE FUNCTION cad.inspect(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_out text := '';
  v_piece record;
  v_joint record;
  v_bbox text;
  v_total_vol real;
  v_count int;
  v_group_count int;
BEGIN
  -- Header
  SELECT count(*), round(sum(ST_Volume(geom))::numeric / 1e9, 4)
  INTO v_count, v_total_vol
  FROM cad.piece WHERE drawing_id = p_drawing_id;

  IF v_count = 0 THEN RETURN 'empty model'; END IF;

  -- Bounding box global
  SELECT format('bbox: [%s, %s, %s] -> [%s, %s, %s]  size: %s x %s x %s mm',
    round(ST_XMin(ext)::numeric), round(ST_YMin(ext)::numeric), round(ST_ZMin(ext)::numeric),
    round(ST_XMax(ext)::numeric), round(ST_YMax(ext)::numeric), round(ST_ZMax(ext)::numeric),
    round((ST_XMax(ext) - ST_XMin(ext))::numeric),
    round((ST_YMax(ext) - ST_YMin(ext))::numeric),
    round((ST_ZMax(ext) - ST_ZMin(ext))::numeric)
  ) INTO v_bbox
  FROM (SELECT ST_3DExtent(geom)::geometry AS ext FROM cad.piece WHERE drawing_id = p_drawing_id) sub;

  v_out := format('model: %s pieces, %s m3 bois', v_count, v_total_vol) || E'\n' || v_bbox || E'\n';

  -- Groupes
  SELECT count(*) INTO v_group_count FROM cad.piece_group WHERE drawing_id = p_drawing_id;
  IF v_group_count > 0 THEN
    v_out := v_out || E'\n' || 'groups (' || v_group_count || '):' || E'\n';
    FOR v_piece IN
      SELECT g.id, g.label, g.parent_id,
        (SELECT count(*) FROM cad.piece p WHERE p.group_id = g.id) AS cnt,
        (SELECT round((sum(ST_Volume(p.geom)) / 1e9)::numeric, 4) FROM cad.piece p WHERE p.group_id = g.id) AS vol
      FROM cad.piece_group g
      WHERE g.drawing_id = p_drawing_id
      ORDER BY g.id
    LOOP
      v_out := v_out || format('  #%s %s (%s pieces, %s m3)', v_piece.id, v_piece.label, v_piece.cnt, coalesce(v_piece.vol::text, '0'));
      IF v_piece.parent_id IS NOT NULL THEN
        v_out := v_out || ' -> parent #' || v_piece.parent_id;
      END IF;
      v_out := v_out || E'\n';
    END LOOP;
  END IF;

  -- Pieces
  v_out := v_out || E'\n' || 'pieces:' || E'\n';
  FOR v_piece IN
    SELECT p.id, p.label, p.role, p.wood_type, p.section, p.length_mm,
      round(ST_XMin(p.geom)::numeric) AS x0, round(ST_YMin(p.geom)::numeric) AS y0, round(ST_ZMin(p.geom)::numeric) AS z0,
      round(ST_XMax(p.geom)::numeric) AS x1, round(ST_YMax(p.geom)::numeric) AS y1, round(ST_ZMax(p.geom)::numeric) AS z1,
      round((ST_Volume(p.geom) / 1e9)::numeric, 6) AS vol_m3,
      g.label AS group_label
    FROM cad.piece p
    LEFT JOIN cad.piece_group g ON g.id = p.group_id
    WHERE p.drawing_id = p_drawing_id ORDER BY p.id
  LOOP
    v_out := v_out || format('  #%s %s [%s] %s %smm  pos:[%s,%s,%s]->[%s,%s,%s]  vol:%s m3',
      v_piece.id, COALESCE(v_piece.label, '-'), v_piece.role,
      v_piece.section, v_piece.length_mm::int,
      v_piece.x0, v_piece.y0, v_piece.z0,
      v_piece.x1, v_piece.y1, v_piece.z1,
      v_piece.vol_m3
    );
    IF v_piece.group_label IS NOT NULL THEN
      v_out := v_out || '  grp:' || v_piece.group_label;
    END IF;
    v_out := v_out || E'\n';
  END LOOP;

  -- Joints (touching pairs)
  v_out := v_out || E'\n' || 'joints:' || E'\n';
  FOR v_joint IN
    SELECT a.id AS a_id, a.label AS a_label, b.id AS b_id, b.label AS b_label,
      ST_3DIntersects(a.geom, b.geom) AS touches
    FROM cad.piece a, cad.piece b
    WHERE a.drawing_id = p_drawing_id AND b.drawing_id = p_drawing_id AND a.id < b.id
    ORDER BY a.id, b.id
  LOOP
    IF v_joint.touches THEN
      v_out := v_out || format('  %s <-> %s : connected',
        COALESCE(v_joint.a_label, '#' || v_joint.a_id),
        COALESCE(v_joint.b_label, '#' || v_joint.b_id)
      ) || E'\n';
    END IF;
  END LOOP;

  RETURN v_out;
END;
$function$;
