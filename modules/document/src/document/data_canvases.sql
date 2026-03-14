CREATE OR REPLACE FUNCTION document.data_canvases(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_category text := NULLIF(trim(COALESCE(p_params->>'p_category', '')), '');
  v_q        text := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_offset   int  := coalesce((p_params->>'_offset')::int, 0);
  v_size     int  := coalesce((p_params->>'_size')::int, 20);
  v_rows     jsonb;
  v_has_more boolean;
BEGIN
  SELECT coalesce(jsonb_agg(row), '[]') INTO v_rows
  FROM (
    SELECT jsonb_build_array(
      c.id,
      c.name,
      c.format || ' ' || c.orientation,
      c.category,
      (SELECT count(*) FROM document.element e WHERE e.canvas_id = c.id)::int,
      to_char(c.updated_at, 'DD/MM/YYYY')
    ) AS row
    FROM document.canvas c
    WHERE c.tenant_id = current_setting('app.tenant_id', true)
      AND (v_category IS NULL OR c.category = v_category)
      AND (v_q IS NULL OR c.name ILIKE '%' || v_q || '%')
    ORDER BY c.updated_at DESC
    LIMIT v_size + 1 OFFSET v_offset
  ) sub;

  v_has_more := jsonb_array_length(v_rows) > v_size;
  IF v_has_more THEN
    v_rows := v_rows - v_size;
  END IF;

  RETURN jsonb_build_object('rows', v_rows, 'has_more', v_has_more);
END;
$function$;
