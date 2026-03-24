CREATE OR REPLACE FUNCTION pgv.ui_link(p_text text, p_href text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'link', 'text', p_text, 'href', p_href);
$function$;
