CREATE OR REPLACE FUNCTION sdui.ui_form(p_uri text, p_verb text, p_fields jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'form', 'uri', p_uri, 'verb', p_verb, 'fields', p_fields);
$function$;
