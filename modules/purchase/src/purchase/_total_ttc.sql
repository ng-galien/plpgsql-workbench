CREATE OR REPLACE FUNCTION purchase._total_ttc(p_commande_id integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN purchase._total_ht(p_commande_id) + purchase._total_tva(p_commande_id);
END;
$function$;
