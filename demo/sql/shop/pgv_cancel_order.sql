CREATE OR REPLACE FUNCTION shop.pgv_cancel_order(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM shop.cancel_order(p_id);
  RETURN '<!-- redirect:/orders/' || p_id || ' -->';
EXCEPTION WHEN OTHERS THEN
  RETURN '<main class="container"><article>'
    || '<header>Error</header>'
    || '<p>' || shop.esc(SQLERRM) || '</p>'
    || '<footer><a href="/orders/' || p_id || '" role="button" class="outline">Back</a></footer>'
    || '</article></main>';
END;
$function$;
