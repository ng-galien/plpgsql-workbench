CREATE OR REPLACE FUNCTION purchase._total_ht(p_commande_id integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN coalesce((
    SELECT sum(quantite * prix_unitaire)
    FROM purchase.ligne
    WHERE commande_id = p_commande_id
  ), 0);
END;
$function$;
