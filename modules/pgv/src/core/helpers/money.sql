CREATE OR REPLACE FUNCTION pgv.money(p_amount numeric)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT to_char(p_amount, 'FM999 999 990D00') || ' EUR';
$function$;
