CREATE OR REPLACE FUNCTION stock._stock_actuel(p_article_id integer, p_depot_id integer DEFAULT NULL::integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_qty numeric;
BEGIN
  IF p_depot_id IS NOT NULL THEN
    SELECT coalesce(sum(quantite), 0) INTO v_qty
    FROM stock.mouvement
    WHERE article_id = p_article_id AND depot_id = p_depot_id;
  ELSE
    SELECT coalesce(sum(quantite), 0) INTO v_qty
    FROM stock.mouvement
    WHERE article_id = p_article_id;
  END IF;
  RETURN v_qty;
END;
$function$;
