CREATE OR REPLACE FUNCTION expense.categorie_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN (SELECT to_jsonb(c) FROM expense.categorie c WHERE c.id = p_id::int);
END;
$function$;
