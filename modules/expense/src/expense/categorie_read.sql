CREATE OR REPLACE FUNCTION expense.categorie_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  v_result := (SELECT to_jsonb(c) FROM expense.categorie c WHERE c.id = p_id::int);

  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN v_result || jsonb_build_object(
    'actions', jsonb_build_array(
      jsonb_build_object('method', 'edit', 'uri', 'expense://categorie/' || (v_result->>'id') || '/edit'),
      jsonb_build_object('method', 'delete', 'uri', 'expense://categorie/' || (v_result->>'id') || '/delete')
    )
  );
END;
$function$;
