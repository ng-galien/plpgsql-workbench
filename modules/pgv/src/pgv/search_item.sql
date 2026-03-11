CREATE OR REPLACE FUNCTION pgv.search_item(p_result pgv.search_result)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<li class="pgv-search-item" data-href="' || pgv.esc(p_result.href) || '">'
    || CASE WHEN p_result.icon IS NOT NULL THEN '<span class="pgv-search-icon">' || p_result.icon || '</span> ' ELSE '' END
    || '<span class="pgv-search-body">'
    || '<strong>' || pgv.esc(p_result.label) || '</strong>'
    || CASE WHEN p_result.kind IS NOT NULL THEN ' ' || pgv.badge(p_result.kind) ELSE '' END
    || CASE WHEN p_result.detail IS NOT NULL THEN '<small>' || pgv.esc(p_result.detail) || '</small>' ELSE '' END
    || '</span>'
    || '</li>';
$function$;
