CREATE OR REPLACE FUNCTION stock._current_stock(p_article_id integer, p_warehouse_id integer DEFAULT NULL::integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_qty numeric;
BEGIN
  IF p_warehouse_id IS NOT NULL THEN
    SELECT coalesce(sum(quantity), 0) INTO v_qty
    FROM stock.movement
    WHERE article_id = p_article_id AND warehouse_id = p_warehouse_id;
  ELSE
    SELECT coalesce(sum(quantity), 0) INTO v_qty
    FROM stock.movement
    WHERE article_id = p_article_id;
  END IF;
  RETURN v_qty;
END;
$function$;
