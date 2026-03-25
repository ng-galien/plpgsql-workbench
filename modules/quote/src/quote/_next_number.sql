CREATE OR REPLACE FUNCTION quote._next_number(p_prefix text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_year text := to_char(now(), 'YYYY');
  v_max int;
  v_pattern text;
BEGIN
  IF p_prefix NOT IN ('EST', 'INV') THEN
    RAISE EXCEPTION 'Invalid prefix: %', p_prefix;
  END IF;

  v_pattern := p_prefix || '-' || v_year || '-%';

  IF p_prefix = 'EST' THEN
    SELECT coalesce(max(substring(number FROM '\d+$')::int), 0)
      INTO v_max FROM quote.estimate WHERE number LIKE v_pattern;
  ELSE
    SELECT coalesce(max(substring(number FROM '\d+$')::int), 0)
      INTO v_max FROM quote.invoice WHERE number LIKE v_pattern;
  END IF;

  RETURN p_prefix || '-' || v_year || '-' || lpad((v_max + 1)::text, 3, '0');
END;
$function$;
