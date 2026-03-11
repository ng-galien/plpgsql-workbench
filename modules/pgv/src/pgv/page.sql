CREATE OR REPLACE FUNCTION pgv.page(p_brand text, p_title text, p_path text, p_nav jsonb, p_body text, p_options jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.nav(p_brand, p_nav, p_path, p_options)
    || '<main class="container">'
    || '<hgroup><h2>' || pgv.esc(p_title) || '</h2></hgroup>'
    || p_body
    || '</main>';
END;
$function$;
