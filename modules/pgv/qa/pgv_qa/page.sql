CREATE OR REPLACE FUNCTION pgv_qa.page(p_path text, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE sql
AS $function$
  SELECT pgv.route('pgv_qa', p_path, p_body);
$function$;
