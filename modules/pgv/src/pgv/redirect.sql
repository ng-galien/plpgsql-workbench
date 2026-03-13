CREATE OR REPLACE FUNCTION pgv.redirect(p_path text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN '<template data-redirect="' || pgv.esc(p_path) || '"></template>';
END;
$function$;
