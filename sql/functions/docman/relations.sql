CREATE OR REPLACE FUNCTION docman.relations(p_doc_id uuid)
 RETURNS TABLE(direction text, related_id uuid, related_file text, kind text, confidence real, assigned_by text)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    CASE WHEN dr.source_id = p_doc_id THEN 'outgoing' ELSE 'incoming' END,
    CASE WHEN dr.source_id = p_doc_id THEN dr.target_id ELSE dr.source_id END,
    f.filename,
    dr.kind,
    dr.confidence,
    dr.assigned_by
  FROM docman.document_relation dr
  JOIN docman.document rd ON rd.id = CASE WHEN dr.source_id = p_doc_id THEN dr.target_id ELSE dr.source_id END
  JOIN docstore.file f ON f.path = rd.file_path
  WHERE dr.source_id = p_doc_id OR dr.target_id = p_doc_id
  ORDER BY dr.kind;
$function$;
