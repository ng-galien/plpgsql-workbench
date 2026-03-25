CREATE OR REPLACE FUNCTION expense.category_create(p_row expense.category)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_result expense.category;
BEGIN
  INSERT INTO expense.category (name, accounting_code) VALUES (p_row.name, p_row.accounting_code) RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
