CREATE OR REPLACE FUNCTION quote._total_ttc(p_estimate_id integer DEFAULT NULL::integer, p_invoice_id integer DEFAULT NULL::integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN quote._total_ht(p_estimate_id, p_invoice_id) + quote._total_tva(p_estimate_id, p_invoice_id);
END;
$function$;
