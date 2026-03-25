CREATE OR REPLACE FUNCTION purchase._remaining_quantity(p_line_id integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN (
    SELECT l.quantity - coalesce(sum(rl.quantity_received), 0)
    FROM purchase.order_line l
    LEFT JOIN purchase.receipt_line rl ON rl.line_id = l.id
    WHERE l.id = p_line_id
    GROUP BY l.quantity
  );
END;
$function$;
