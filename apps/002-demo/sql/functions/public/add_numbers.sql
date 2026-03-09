CREATE OR REPLACE FUNCTION public.add_numbers(a integer, b integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN a + b;
END;
$function$;
