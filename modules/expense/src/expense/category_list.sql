CREATE OR REPLACE FUNCTION expense.category_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY SELECT to_jsonb(c) FROM expense.category c ORDER BY c.name;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(c) FROM expense.category c WHERE '
      || pgv.rsql_to_where(p_filter, 'expense', 'category') || ' ORDER BY c.name';
  END IF;
END;
$function$;
