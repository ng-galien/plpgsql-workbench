CREATE OR REPLACE FUNCTION docman.search(p_filters jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_sql TEXT;
  v_where TEXT[] := ARRAY[]::TEXT[];
  v_result JSONB;
  v_limit INT;
BEGIN
  v_limit := coalesce((p_filters->>'limit')::INT, 30);

  IF p_filters->>'name' IS NOT NULL THEN
    v_where := array_append(v_where, format('f.filename ILIKE %L', p_filters->>'name'));
  END IF;

  IF p_filters->>'doc_type' IS NOT NULL THEN
    v_where := array_append(v_where, format('d.doc_type = %L', p_filters->>'doc_type'));
  END IF;

  IF p_filters->>'extension' IS NOT NULL THEN
    v_where := array_append(v_where, format('f.extension = %L',
      CASE WHEN left(p_filters->>'extension', 1) = '.' THEN p_filters->>'extension'
           ELSE '.' || (p_filters->>'extension') END));
  END IF;

  IF p_filters->>'source' IS NOT NULL THEN
    v_where := array_append(v_where, format('d.source = %L', p_filters->>'source'));
  END IF;

  IF p_filters->>'after' IS NOT NULL THEN
    v_where := array_append(v_where, format('d.document_date >= %L::date', p_filters->>'after'));
  END IF;

  IF p_filters->>'before' IS NOT NULL THEN
    v_where := array_append(v_where, format('d.document_date < %L::date', p_filters->>'before'));
  END IF;

  IF p_filters->>'label' IS NOT NULL THEN
    v_where := array_append(v_where, format(
      'EXISTS (SELECT 1 FROM docman.document_label dl JOIN docman.label l ON l.id = dl.label_id WHERE dl.document_id = d.id AND l.name = %L)',
      p_filters->>'label'));
  END IF;

  IF p_filters->>'entity' IS NOT NULL THEN
    v_where := array_append(v_where, format(
      'EXISTS (SELECT 1 FROM docman.document_entity de JOIN docman.entity e ON e.id = de.entity_id WHERE de.document_id = d.id AND e.name = %L)',
      p_filters->>'entity'));
  END IF;

  IF (p_filters->>'classified')::BOOLEAN IS NOT NULL THEN
    IF (p_filters->>'classified')::BOOLEAN THEN
      v_where := array_append(v_where, 'd.classified_at IS NOT NULL');
    ELSE
      v_where := array_append(v_where, 'd.classified_at IS NULL');
    END IF;
  END IF;

  IF p_filters->>'q' IS NOT NULL THEN
    v_where := array_append(v_where, format(
      'd.summary_tsv @@ plainto_tsquery(''french'', %L)', p_filters->>'q'));
  END IF;

  v_sql := 'SELECT jsonb_agg(row_doc ORDER BY created_at DESC) FROM (
    SELECT jsonb_build_object(
      ''id'', d.id,
      ''file_path'', d.file_path,
      ''filename'', f.filename,
      ''extension'', f.extension,
      ''size_bytes'', f.size_bytes,
      ''doc_type'', d.doc_type,
      ''document_date'', d.document_date,
      ''source'', d.source,
      ''summary'', d.summary,
      ''classified_at'', d.classified_at,
      ''created_at'', d.created_at
    ) AS row_doc, d.created_at
    FROM docman.document d
    JOIN docstore.file f ON f.path = d.file_path';

  IF array_length(v_where, 1) > 0 THEN
    v_sql := v_sql || ' WHERE ' || array_to_string(v_where, ' AND ');
  END IF;

  v_sql := v_sql || format(' LIMIT %s) sub', v_limit);

  EXECUTE v_sql INTO v_result;

  RETURN coalesce(v_result, '[]'::jsonb);
END;
$function$;
