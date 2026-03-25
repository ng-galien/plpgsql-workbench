CREATE OR REPLACE FUNCTION expense._next_reference()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_year text := extract(year FROM now())::text;
  v_max int;
BEGIN
  SELECT max(substring(reference FROM 'NDF-' || v_year || '-(\d+)')::int)
  INTO v_max
  FROM expense.expense_report
  WHERE reference LIKE 'NDF-' || v_year || '-%';
  RETURN 'NDF-' || v_year || '-' || lpad((coalesce(v_max, 0) + 1)::text, 3, '0');
END;
$function$;
