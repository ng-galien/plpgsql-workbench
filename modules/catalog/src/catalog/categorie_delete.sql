CREATE OR REPLACE FUNCTION catalog.categorie_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row catalog.categorie;
BEGIN
  DELETE FROM catalog.categorie WHERE id = p_id::int RETURNING * INTO v_row;
  RETURN to_jsonb(v_row);
END;
$function$;
