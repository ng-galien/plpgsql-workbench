CREATE OR REPLACE FUNCTION catalog.category_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row catalog.category;
BEGIN
  DELETE FROM catalog.category WHERE id = p_id::int RETURNING * INTO v_row;
  RETURN to_jsonb(v_row);
END;
$function$;
