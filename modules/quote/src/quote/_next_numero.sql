CREATE OR REPLACE FUNCTION quote._next_numero(p_prefix text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_year text := to_char(now(), 'YYYY');
  v_count int;
BEGIN
  IF p_prefix = 'DEV' THEN
    SELECT count(*) INTO v_count
    FROM quote.devis
    WHERE numero LIKE 'DEV-' || v_year || '-%';
  ELSIF p_prefix = 'FAC' THEN
    SELECT count(*) INTO v_count
    FROM quote.facture
    WHERE numero LIKE 'FAC-' || v_year || '-%';
  ELSE
    RAISE EXCEPTION 'Préfixe invalide: %', p_prefix;
  END IF;

  RETURN p_prefix || '-' || v_year || '-' || lpad((v_count + 1)::text, 3, '0');
END;
$function$;
