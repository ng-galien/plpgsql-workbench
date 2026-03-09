CREATE OR REPLACE FUNCTION public.classify(x integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF x > 0 THEN
    RETURN 'positive';
  ELSIF x = 0 THEN
    RETURN 'zero';
  ELSE
    RETURN 'negative';
  END IF;
END;
$function$;
