CREATE OR REPLACE FUNCTION cad.drawing_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT to_jsonb(d) || jsonb_build_object(
      'shape_count', (SELECT count(*) FROM cad.shape s WHERE s.drawing_id = d.id),
      'piece_count', (SELECT count(*) FROM cad.piece p WHERE p.drawing_id = d.id),
      'layer_count', (SELECT count(*) FROM cad.layer l WHERE l.drawing_id = d.id)
    )
    FROM cad.drawing d
    WHERE d.tenant_id = current_setting('app.tenant_id', true)
    ORDER BY d.updated_at DESC;
END;
$function$;
