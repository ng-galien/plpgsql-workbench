CREATE OR REPLACE FUNCTION docman.entity_kinds()
 RETURNS TABLE(kind text, count bigint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT e.kind, count(*) AS count
  FROM docman.entity e
  GROUP BY e.kind
  ORDER BY e.kind;
$function$;
