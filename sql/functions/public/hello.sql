CREATE OR REPLACE FUNCTION public.hello(name text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN 'Hello ' || name;
END;
$function$;
