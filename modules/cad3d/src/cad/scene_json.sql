CREATE OR REPLACE FUNCTION cad.scene_json(p_drawing_id integer)
 RETURNS jsonb
 LANGUAGE sql
AS $function$
  SELECT COALESCE(jsonb_agg(piece_data), '[]'::jsonb)
  FROM (
    SELECT jsonb_build_object(
      'id', p.id,
      'label', p.label,
      'role', p.role,
      'wood_type', p.wood_type,
      'section', p.section,
      'length_mm', p.length_mm,
      'mesh', (
        SELECT ST_AsGeoJSON(ST_Collect(tri.geom))::jsonb
        FROM ST_Dump(p.geom) AS face,
             LATERAL ST_Dump(ST_Tesselate(face.geom)) AS tri
      )
    ) AS piece_data
    FROM cad.piece p
    WHERE p.drawing_id = p_drawing_id
  ) sub;
$function$;
