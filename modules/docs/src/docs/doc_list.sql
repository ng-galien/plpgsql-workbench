CREATE OR REPLACE FUNCTION docs.doc_list()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb := '[]'::jsonb;
  r record;
BEGIN
  FOR r IN
    SELECT d.id, d.name, d.category, d.format, d.orientation, d.status, d.rating,
           c.name AS charte_name,
           (SELECT count(*) FROM docs.page p WHERE p.doc_id = d.id) AS nb_pages,
           d.updated_at
    FROM docs.document d
    LEFT JOIN docs.charte c ON c.id = d.charte_id
    WHERE d.tenant_id = current_setting('app.tenant_id', true)
    ORDER BY d.category, d.updated_at DESC
  LOOP
    v_result := v_result || jsonb_build_object(
      'id', r.id, 'name', r.name, 'category', r.category,
      'format', r.format, 'orientation', r.orientation,
      'status', r.status, 'rating', r.rating,
      'charte', r.charte_name, 'pages', r.nb_pages,
      'updated_at', r.updated_at
    );
  END LOOP;
  RETURN v_result;
END;
$function$;
