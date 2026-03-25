CREATE OR REPLACE FUNCTION purchase._total_ttc(p_order_id integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN purchase._total_ht(p_order_id) + purchase._total_tva(p_order_id);
END;
$function$;
