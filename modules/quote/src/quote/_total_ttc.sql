CREATE OR REPLACE FUNCTION quote._total_ttc(p_devis_id integer DEFAULT NULL::integer, p_facture_id integer DEFAULT NULL::integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN quote._total_ht(p_devis_id, p_facture_id) + quote._total_tva(p_devis_id, p_facture_id);
END;
$function$;
