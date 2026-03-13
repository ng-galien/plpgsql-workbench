CREATE OR REPLACE FUNCTION asset.search(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_status TEXT   := NULLIF(trim(COALESCE(p_params->>'p_status', '')), '');
  v_tags   TEXT[] := CASE WHEN p_params ? 'p_tags' AND p_params->>'p_tags' IS NOT NULL
                       THEN ARRAY(SELECT jsonb_array_elements_text(p_params->'p_tags'))
                       ELSE NULL END;
  v_q      TEXT   := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_mime   TEXT   := NULLIF(trim(COALESCE(p_params->>'p_mime', '')), '');
  v_offset INT    := coalesce((p_params->>'_offset')::int, 0);
  v_size   INT    := coalesce((p_params->>'_size')::int, 20);
  v_rows   JSONB;
  v_has_more BOOLEAN;
BEGIN
  SELECT coalesce(jsonb_agg(row_to_json(sub)::jsonb), '[]') INTO v_rows
  FROM (
    SELECT a.id, a.filename, a.path, a.mime_type, a.status,
           a.title, a.description, a.tags, a.width, a.height,
           a.orientation, a.saison, a.credit, a.usage_hint, a.colors,
           a.created_at, a.classified_at
    FROM asset.asset a
    WHERE (v_status IS NULL OR a.status = v_status)
      AND (v_tags IS NULL OR a.tags && v_tags)
      AND (v_q IS NULL OR a.search_vec @@ plainto_tsquery('pgv_search', v_q))
      AND (v_mime IS NULL OR a.mime_type ILIKE v_mime || '%')
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
