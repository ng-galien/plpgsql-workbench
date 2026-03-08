CREATE OR REPLACE FUNCTION public.process(x integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  result text := '';
BEGIN
  IF x > 10 THEN
    result := 'big';
  END IF;
  FOR i IN 1..x LOOP
    result := result || '.';
  END LOOP;
  RETURN result;
END;
$function$;
