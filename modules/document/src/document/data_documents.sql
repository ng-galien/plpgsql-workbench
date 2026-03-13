CREATE OR REPLACE FUNCTION document.data_documents(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_doc_type text   := NULLIF(trim(COALESCE(p_params->>'p_doc_type', '')), '');
  v_status   text   := NULLIF(trim(COALESCE(p_params->>'p_status', '')), '');
  v_q        text   := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_offset   int    := coalesce((p_params->>'_offset')::int, 0);
  v_size     int    := coalesce((p_params->>'_size')::int, 20);
  v_rows     jsonb;
  v_has_more boolean;
BEGIN
  SELECT coalesce(jsonb_agg(row), '[]') INTO v_rows
  FROM (
    SELECT jsonb_build_array(
      d.id,
      d.title,
      d.doc_type,
      COALESCE(d.ref_module, '—'),
      COALESCE(d.ref_id, '—'),
      d.status,
      to_char(d.created_at, 'DD/MM/YYYY')
    ) AS row
    FROM document.document d
    WHERE d.tenant_id = current_setting('app.tenant_id', true)
      AND (v_doc_type IS NULL OR d.doc_type = v_doc_type)
      AND (v_status IS NULL OR d.status = v_status)
      AND (v_q IS NULL OR d.title ILIKE '%' || v_q || '%')
    ORDER BY d.created_at DESC
    LIMIT v_size + 1 OFFSET v_offset
  ) sub;

  v_has_more := jsonb_array_length(v_rows) > v_size;
  IF v_has_more THEN
    v_rows := v_rows - v_size;
  END IF;

  RETURN jsonb_build_object('rows', v_rows, 'has_more', v_has_more);
END;
$function$;
