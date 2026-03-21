CREATE OR REPLACE FUNCTION document.xhtml_validate(p_html text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN xml_is_well_formed('<root>' || COALESCE(p_html, '') || '</root>');
END;
$function$;
