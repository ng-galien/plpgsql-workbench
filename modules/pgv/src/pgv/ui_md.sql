CREATE OR REPLACE FUNCTION pgv.ui_md(p_content text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'md', 'content', p_content);
$function$;
