CREATE OR REPLACE FUNCTION docman.inbox(p_limit integer DEFAULT 20, p_max_confidence real DEFAULT NULL::real)
 RETURNS TABLE(id uuid, file_path text, filename text, extension text, size_bytes bigint, doc_type text, source text, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT d.id, d.file_path, f.filename, f.extension, f.size_bytes,
         d.doc_type, d.source, d.created_at
  FROM docman.document d
  JOIN docstore.file f ON f.path = d.file_path
  WHERE
    CASE
      WHEN p_max_confidence IS NULL THEN
        d.classified_at IS NULL
      ELSE
        d.classified_at IS NULL
        OR EXISTS (
          SELECT 1 FROM docman.document_label dl
          WHERE dl.document_id = d.id AND dl.confidence <= p_max_confidence
        )
    END
  ORDER BY d.created_at DESC
  LIMIT p_limit;
$function$;
