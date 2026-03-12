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
      pgv.esc(a.designation)),
    '' ORDER BY a.designation
  ), '')
FROM catalog.article a
WHERE a.actif;
$function$;
