CREATE OR REPLACE FUNCTION shop.pgv_money(p_amount numeric)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '$' || to_char(COALESCE(p_amount, 0), 'FM999,999,990.00');
$function$;
