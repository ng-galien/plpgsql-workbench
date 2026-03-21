CREATE OR REPLACE FUNCTION document.library_list()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb := '[]'::jsonb;
  r record;
BEGIN
  FOR r IN
    SELECT l.id, l.name, l.description,
           (SELECT count(*) FROM document.library_asset la WHERE la.library_id = l.id) AS asset_cnt,
           l.created_at
    FROM document.library l
    WHERE l.tenant_id = current_setting('app.tenant_id', true)
    ORDER BY l.name
  LOOP
    v_result := v_result || jsonb_build_object(
      'id', r.id, 'name', r.name, 'description', r.description,
      'assets', r.asset_cnt, 'created_at', r.created_at
    );
  END LOOP;
  RETURN v_result;
END;
$function$;
