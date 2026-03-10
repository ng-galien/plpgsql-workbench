CREATE OR REPLACE FUNCTION pgv.page(p_brand text, p_title text, p_path text, p_nav jsonb, p_body text)
 RETURNS "text/html"
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN pgv.nav(p_brand, p_nav, p_path)
    || '<main class="container">'
    || '<hgroup><h2>' || pgv.esc(p_title) || '</h2></hgroup>'
    || p_body
    || '</main>';
END;
$function$;
