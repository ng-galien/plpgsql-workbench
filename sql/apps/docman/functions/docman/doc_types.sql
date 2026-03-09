CREATE OR REPLACE FUNCTION docman.doc_types()
 RETURNS TABLE(doc_type text, count bigint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT d.doc_type, count(*) AS count
  FROM docman.document d
  WHERE d.doc_type IS NOT NULL
  GROUP BY d.doc_type
  ORDER BY d.doc_type;
$function$;
