CREATE OR REPLACE FUNCTION quote._next_numero(p_prefix text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_year text := to_char(now(), 'YYYY');
  v_max int;
  v_pattern text;
BEGIN
  v_pattern := p_prefix || '-' || v_year || '-';

  IF p_prefix = 'DEV' THEN
    SELECT coalesce(max(substring(numero FROM length(v_pattern) + 1)::int), 0)
      INTO v_max
      FROM quote.devis
     WHERE numero LIKE v_pattern || '%';
  ELSIF p_prefix = 'FAC' THEN
    SELECT coalesce(max(substring(numero FROM length(v_pattern) + 1)::int), 0)
      INTO v_max
      FROM quote.facture
     WHERE numero LIKE v_pattern || '%';
  ELSE
    RAISE EXCEPTION 'Préfixe invalide: %', p_prefix;
  END IF;

  RETURN v_pattern || lpad((v_max + 1)::text, 3, '0');
END;
$function$;
