CREATE OR REPLACE FUNCTION app.frag_search(p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE sql
AS $function$
  SELECT docman.frag_search(p_body);
$function$;
