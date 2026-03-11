CREATE OR REPLACE FUNCTION cad_qa.page(p_path text, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE sql
AS $function$
  SELECT pgv.route('cad_qa', p_path, 'GET', p_body);
$function$;
