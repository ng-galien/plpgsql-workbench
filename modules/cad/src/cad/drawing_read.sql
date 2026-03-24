CREATE OR REPLACE FUNCTION cad.drawing_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN (
    SELECT to_jsonb(d) || jsonb_build_object(
      'shape_count', (SELECT count(*) FROM cad.shape s WHERE s.drawing_id = d.id),
      'piece_count', (SELECT count(*) FROM cad.piece p WHERE p.drawing_id = d.id),
      'layer_count', (SELECT count(*) FROM cad.layer l WHERE l.drawing_id = d.id),
      'group_count', (SELECT count(*) FROM cad.piece_group g WHERE g.drawing_id = d.id)
    )
    FROM cad.drawing d
    WHERE d.id = p_id::int
      AND d.tenant_id = current_setting('app.tenant_id', true)
  );
END;
$function$;
