CREATE OR REPLACE FUNCTION catalog.article_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row catalog.article;
BEGIN
  DELETE FROM catalog.article WHERE id = p_id::int RETURNING * INTO v_row;
  RETURN to_jsonb(v_row);
END;
$function$;
