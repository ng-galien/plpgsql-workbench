CREATE OR REPLACE FUNCTION pgv.toast(p_message text, p_level text DEFAULT 'success'::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN '<template data-toast="' || pgv.esc(p_level) || '">' || pgv.esc(p_message) || '</template>';
END;
$function$;
