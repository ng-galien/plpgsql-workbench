CREATE OR REPLACE FUNCTION catalog.article_options()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
SELECT coalesce(
  string_agg(
    format('<option value="%s">%s - %s</option>',
      a.id,
      pgv.esc(coalesce(a.reference, '#' || a.id)),
      pgv.esc(a.name)),
    '' ORDER BY a.name
  ), '')
FROM catalog.article a
WHERE a.active;
$function$;
