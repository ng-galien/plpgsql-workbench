CREATE OR REPLACE FUNCTION docs.library_read(p_library_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_lib docs.library;
  v_assets jsonb := '[]'::jsonb;
  r record;
BEGIN
  SELECT * INTO v_lib FROM docs.library WHERE id = p_library_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_lib IS NULL THEN RETURN NULL; END IF;

  FOR r IN
    SELECT a.id, a.filename, a.title, a.description, a.tags, a.width, a.height, a.mime_type, a.path,
           la.role, la.context, la.sort_order
    FROM docs.library_asset la
    JOIN asset.asset a ON a.id = la.asset_id
    WHERE la.library_id = p_library_id
    ORDER BY la.sort_order, a.filename
  LOOP
    v_assets := v_assets || jsonb_build_object(
      'id', r.id, 'filename', r.filename, 'title', r.title,
      'description', r.description, 'tags', r.tags,
      'width', r.width, 'height', r.height, 'mime_type', r.mime_type, 'path', r.path,
      'role', r.role, 'context', r.context, 'sort_order', r.sort_order
    );
  END LOOP;

  RETURN jsonb_build_object(
    'id', v_lib.id,
    'name', v_lib.name,
    'description', v_lib.description,
    'assets', v_assets
  );
END;
$function$;
