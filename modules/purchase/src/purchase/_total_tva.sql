CREATE OR REPLACE FUNCTION purchase._total_tva(p_order_id integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN coalesce((
    SELECT sum(quantity * unit_price * tva_rate / 100)
    FROM purchase.order_line
    WHERE order_id = p_order_id
  ), 0);
END;
$function$;
