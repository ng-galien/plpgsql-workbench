CREATE OR REPLACE FUNCTION quote._total_ht(p_devis_id integer DEFAULT NULL::integer, p_facture_id integer DEFAULT NULL::integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN COALESCE((
    SELECT sum(round(quantite * prix_unitaire, 2))
    FROM quote.ligne
    WHERE devis_id IS NOT DISTINCT FROM p_devis_id
      AND facture_id IS NOT DISTINCT FROM p_facture_id
  ), 0);
END;
$function$;
