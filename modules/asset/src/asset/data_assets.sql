CREATE OR REPLACE FUNCTION asset.data_assets(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_status   TEXT   := NULLIF(trim(COALESCE(p_params->>'p_status', '')), '');
  v_q        TEXT   := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_offset   INT    := coalesce((p_params->>'_offset')::int, 0);
  v_size     INT    := coalesce((p_params->>'_size')::int, 20);
  v_rows     JSONB;
  v_has_more BOOLEAN;
BEGIN
  SELECT coalesce(jsonb_agg(row), '[]') INTO v_rows
  FROM (
    SELECT jsonb_build_array(
      a.id,
      a.filename,
      COALESCE(a.title, '—'),
      a.mime_type,
      a.status,
      COALESCE(array_to_string(a.tags, ', '), ''),
      to_char(a.created_at, 'DD/MM/YYYY')
    ) AS row
    FROM asset.asset a
    WHERE (v_status IS NULL OR a.status = v_status)
      AND (v_q IS NULL OR a.search_vec @@ plainto_tsquery('pgv_search', v_q))
    ORDER BY a.created_at DESC
    LIMIT v_size + 1 OFFSET v_offset
  ) sub;

  v_has_more := jsonb_array_length(v_rows) > v_size;
  IF v_has_more THEN
    v_rows := v_rows - v_size;
  END IF;

  RETURN jsonb_build_object('rows', v_rows, 'has_more', v_has_more);
END;
$function$;
