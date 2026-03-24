CREATE OR REPLACE FUNCTION expense.categorie_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(c)
      FROM expense.categorie c
      ORDER BY c.nom;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(c)
       FROM expense.categorie c
       WHERE ' || pgv.rsql_to_where(p_filter, 'expense', 'categorie')
       || ' ORDER BY c.nom';
  END IF;
END;
$function$;
