CREATE OR REPLACE FUNCTION stock._recalc_wap(p_article_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_total_qty numeric := 0;
  v_total_val numeric := 0;
  r record;
BEGIN
  FOR r IN
    SELECT quantity, unit_price
    FROM stock.movement
    WHERE article_id = p_article_id AND type = 'entry'
    ORDER BY created_at
  LOOP
    v_total_val := v_total_val + (r.quantity * coalesce(r.unit_price, 0));
    v_total_qty := v_total_qty + r.quantity;
  END LOOP;

  UPDATE stock.article
  SET wap = CASE WHEN v_total_qty > 0 THEN v_total_val / v_total_qty ELSE 0 END
  WHERE id = p_article_id;
END;
$function$;
