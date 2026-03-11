CREATE OR REPLACE FUNCTION pgv_qa.lazy_diagnose(p_path text)
 RETURNS "text/html"
 LANGUAGE sql
AS $function$
  SELECT pgv.diagnose('pgv_qa', p_path);
$function$;
