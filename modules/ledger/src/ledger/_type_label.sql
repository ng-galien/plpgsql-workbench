CREATE OR REPLACE FUNCTION ledger._type_label(p_type text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN CASE p_type
    WHEN 'asset'     THEN 'Actif'
    WHEN 'liability' THEN 'Passif'
    WHEN 'equity'    THEN 'Capitaux'
    WHEN 'revenue'   THEN 'Produit'
    WHEN 'expense'   THEN 'Charge'
    ELSE p_type
  END;
END;
$function$;
