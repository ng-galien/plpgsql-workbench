CREATE OR REPLACE FUNCTION purchase._total_tva(p_commande_id integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN coalesce((
    SELECT sum(quantite * prix_unitaire * tva_rate / 100)
    FROM purchase.ligne
    WHERE commande_id = p_commande_id
  ), 0);
END;
$function$;
