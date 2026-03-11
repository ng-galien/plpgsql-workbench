CREATE OR REPLACE FUNCTION ledger._type_sign(p_type text)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN CASE
    WHEN p_type IN ('asset', 'expense') THEN 1
    WHEN p_type IN ('liability', 'equity', 'revenue') THEN -1
    ELSE NULL
  END;
END;
$function$;
