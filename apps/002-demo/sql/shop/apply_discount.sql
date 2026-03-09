CREATE OR REPLACE FUNCTION shop.apply_discount(p_code text, p_subtotal numeric, p_item_count integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_disc shop.discounts;
  v_amount numeric := 0;
  v_free_items integer;
BEGIN
  SELECT * INTO v_disc FROM shop.discounts WHERE code = p_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'discount code "%" not found', p_code;
  END IF;

  IF NOT v_disc.active THEN
    RAISE EXCEPTION 'discount code "%" is inactive', p_code;
  END IF;

  IF v_disc.expires_at IS NOT NULL AND v_disc.expires_at < now() THEN
    RAISE EXCEPTION 'discount code "%" has expired', p_code;
  END IF;

  IF p_subtotal < v_disc.min_order THEN
    RAISE EXCEPTION 'minimum order % required for discount "%"', v_disc.min_order, p_code;
  END IF;

  CASE v_disc.kind
    WHEN 'percentage' THEN
      v_amount := ROUND(p_subtotal * v_disc.value / 100, 2);
    WHEN 'fixed' THEN
      v_amount := LEAST(v_disc.value, p_subtotal);
    WHEN 'buy_x_get_y' THEN
      IF p_item_count >= v_disc.buy_x THEN
        v_free_items := (p_item_count / v_disc.buy_x) * v_disc.get_y_free;
        v_amount := ROUND(v_free_items * (p_subtotal / p_item_count), 2);
      END IF;
  END CASE;

  RETURN v_amount;
END;
$function$;
