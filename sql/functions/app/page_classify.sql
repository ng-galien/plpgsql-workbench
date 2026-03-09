CREATE OR REPLACE FUNCTION app.page_classify(p_doc_id uuid, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE sql
AS $function$
  SELECT docman.page_classify(p_doc_id, p_body);
$function$;
