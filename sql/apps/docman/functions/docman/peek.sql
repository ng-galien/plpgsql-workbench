CREATE OR REPLACE FUNCTION docman.peek(p_doc_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_doc JSONB;
  v_labels JSONB;
  v_entities JSONB;
  v_relations JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', d.id,
    'file_path', d.file_path,
    'filename', f.filename,
    'extension', f.extension,
    'size_bytes', f.size_bytes,
    'mime_type', f.mime_type,
    'doc_type', d.doc_type,
    'document_date', d.document_date,
    'source', d.source,
    'source_ref', d.source_ref,
    'summary', d.summary,
    'classified_at', d.classified_at,
    'created_at', d.created_at
  ) INTO v_doc
  FROM docman.document d
  JOIN docstore.file f ON f.path = d.file_path
  WHERE d.id = p_doc_id;

  IF v_doc IS NULL THEN
    RETURN jsonb_build_object('error', 'document not found');
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'label_id', l.id,
    'name', l.name,
    'kind', l.kind,
    'confidence', dl.confidence,
    'assigned_by', dl.assigned_by
  ) ORDER BY l.kind, l.name), '[]'::jsonb)
  INTO v_labels
  FROM docman.document_label dl
  JOIN docman.label l ON l.id = dl.label_id
  WHERE dl.document_id = p_doc_id;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'entity_id', e.id,
    'kind', e.kind,
    'name', e.name,
    'role', de.role,
    'confidence', de.confidence,
    'assigned_by', de.assigned_by
  ) ORDER BY e.kind, e.name), '[]'::jsonb)
  INTO v_entities
  FROM docman.document_entity de
  JOIN docman.entity e ON e.id = de.entity_id
  WHERE de.document_id = p_doc_id;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'direction', CASE WHEN dr.source_id = p_doc_id THEN 'outgoing' ELSE 'incoming' END,
    'related_id', CASE WHEN dr.source_id = p_doc_id THEN dr.target_id ELSE dr.source_id END,
    'related_file', f.filename,
    'kind', dr.kind,
    'confidence', dr.confidence,
    'assigned_by', dr.assigned_by
  ) ORDER BY dr.kind), '[]'::jsonb)
  INTO v_relations
  FROM docman.document_relation dr
  JOIN docman.document rd ON rd.id = CASE WHEN dr.source_id = p_doc_id THEN dr.target_id ELSE dr.source_id END
  JOIN docstore.file f ON f.path = rd.file_path
  WHERE dr.source_id = p_doc_id OR dr.target_id = p_doc_id;

  RETURN v_doc || jsonb_build_object(
    'labels', v_labels,
    'entities', v_entities,
    'relations', v_relations
  );
END;
$function$;
