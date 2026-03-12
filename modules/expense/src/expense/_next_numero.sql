CREATE OR REPLACE FUNCTION expense._next_numero()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_year text := to_char(now(), 'YYYY');
  v_pattern text := 'NDF-' || v_year || '-';
  v_max int;
BEGIN
  SELECT coalesce(max(substring(reference FROM length(v_pattern) + 1)::int), 0)
    INTO v_max
    FROM expense.note
   WHERE reference LIKE v_pattern || '%';

  RETURN v_pattern || lpad((v_max + 1)::text, 3, '0');
END;
$function$;
