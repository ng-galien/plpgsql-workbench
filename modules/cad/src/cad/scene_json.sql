CREATE OR REPLACE FUNCTION cad.scene_json(p_drawing_id integer)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_pieces jsonb;
  v_groups jsonb;
  v_total_volume numeric;
BEGIN
  -- Pièces avec info groupe
  SELECT COALESCE(jsonb_agg(piece_data), '[]'::jsonb) INTO v_pieces
  FROM (
    SELECT jsonb_build_object(
      'id', p.id,
      'label', p.label,
      'role', p.role,
      'wood_type', p.wood_type,
      'section', p.section,
      'length_mm', p.length_mm,
      'group_id', p.group_id,
      'group_label', g.label,
      'mesh', (
        SELECT ST_AsGeoJSON(ST_Collect(tri.geom))::jsonb
        FROM ST_Dump(p.geom) AS face,
             LATERAL ST_Dump(ST_Tesselate(face.geom)) AS tri
      )
    ) AS piece_data
    FROM cad.piece p
    LEFT JOIN cad.piece_group g ON g.id = p.group_id
    WHERE p.drawing_id = p_drawing_id
  ) sub;

  -- Hiérarchie des groupes
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', id, 'label', label, 'parent_id', parent_id
  )), '[]'::jsonb) INTO v_groups
  FROM cad.piece_group
  WHERE drawing_id = p_drawing_id;

  -- Volume total PostGIS (m³)
  SELECT COALESCE(round((sum(ST_Volume(geom)) / 1e9)::numeric, 6), 0)
  INTO v_total_volume
  FROM cad.piece
  WHERE drawing_id = p_drawing_id;

  RETURN jsonb_build_object('pieces', v_pieces, 'groups', v_groups, 'total_volume', v_total_volume);
END;
$function$;
