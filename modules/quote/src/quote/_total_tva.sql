CREATE OR REPLACE FUNCTION quote._total_tva(p_estimate_id integer DEFAULT NULL::integer, p_invoice_id integer DEFAULT NULL::integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN COALESCE((
    SELECT sum(round(quantity * unit_price * tva_rate / 100, 2))
    FROM quote.line_item
    WHERE estimate_id IS NOT DISTINCT FROM p_estimate_id
      AND invoice_id IS NOT DISTINCT FROM p_invoice_id
  ), 0);
END;
$function$;
