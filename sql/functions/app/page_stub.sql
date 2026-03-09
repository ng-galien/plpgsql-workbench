CREATE OR REPLACE FUNCTION app.page_stub(p_path text, p_section text)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.page(p_section, p_path, app.nav_items(),
    pgv.card(null,
      '<p>Page <code>' || pgv.esc(p_path) || '</code> en construction.</p>'
      || '<p><a href="/" hx-get="/rpc/page?p_path=/" hx-push-url="/">Retour au dashboard</a></p>'
    )
  );
END;
$function$;
