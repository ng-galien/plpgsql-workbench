CREATE OR REPLACE FUNCTION purchase._next_number(p_prefix text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_year text := to_char(now(), 'YYYY');
  v_seq int;
BEGIN
  SELECT coalesce(max(
    regexp_replace(number, '^.*-(\d+)$', '\1')::int
  ), 0) + 1
  INTO v_seq
  FROM purchase.purchase_order
  WHERE number LIKE p_prefix || '-' || v_year || '-%'
  UNION ALL
  SELECT coalesce(max(
    regexp_replace(number, '^.*-(\d+)$', '\1')::int
  ), 0) + 1
  FROM purchase.receipt
  WHERE number LIKE p_prefix || '-' || v_year || '-%'
  ORDER BY 1 DESC LIMIT 1;

  RETURN p_prefix || '-' || v_year || '-' || lpad(v_seq::text, 3, '0');
END;
$function$;
