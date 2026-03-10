CREATE OR REPLACE FUNCTION pgv.error(p_status text, p_title text, p_detail text DEFAULT NULL::text, p_hint text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE v_html text;
BEGIN
  v_html := '<article class="pgv-error">'
    || '<header><strong>' || pgv.esc(p_status) || E' \u2014 ' || pgv.esc(p_title) || '</strong></header>';
  IF p_detail IS NOT NULL THEN v_html := v_html || '<p>' || pgv.esc(p_detail) || '</p>'; END IF;
  IF p_hint IS NOT NULL THEN v_html := v_html || '<p><small>' || pgv.esc(p_hint) || '</small></p>'; END IF;
  v_html := v_html || '<footer><a href="/">Retour au dashboard</a></footer></article>';
  RETURN v_html;
END;
$function$;
