CREATE OR REPLACE FUNCTION pgv.grid(VARIADIC p_items text[])
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<div class="grid">' || array_to_string(p_items, '') || '</div>';
$function$;
