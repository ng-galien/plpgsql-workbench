CREATE OR REPLACE FUNCTION pgv_qa.data_demo(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_page int := coalesce((p_params->>'_page')::int, 1);
  v_size int := coalesce((p_params->>'_size')::int, 20);
  v_status text := p_params->>'p_status';
  v_q text := p_params->>'q';
  v_all jsonb;
  v_filtered jsonb;
  v_total int;
  v_rows jsonb;
BEGIN
  -- Generate 50 demo rows
  SELECT jsonb_agg(row) INTO v_all FROM (
    SELECT jsonb_build_array(
      i,
      CASE i % 3 WHEN 0 THEN 'Alice' WHEN 1 THEN 'Bob' ELSE 'Charlie' END,
      'Item ' || i,
      CASE i % 4 WHEN 0 THEN 'active' WHEN 1 THEN 'draft' WHEN 2 THEN 'archived' ELSE 'active' END,
      to_char(now() - (i || ' hours')::interval, 'YYYY-MM-DD HH24:MI')
    ) AS row
    FROM generate_series(1, 50) AS i
  ) sub;

  -- Apply filters
  SELECT jsonb_agg(r) INTO v_filtered FROM jsonb_array_elements(v_all) AS r
  WHERE (v_status IS NULL OR v_status = '' OR r->>3 = v_status)
    AND (v_q IS NULL OR v_q = '' OR r->>2 ILIKE '%' || v_q || '%' OR r->>1 ILIKE '%' || v_q || '%');

  v_filtered := coalesce(v_filtered, '[]'::jsonb);
  v_total := jsonb_array_length(v_filtered);

  -- Paginate
  SELECT jsonb_agg(r) INTO v_rows FROM (
    SELECT r FROM jsonb_array_elements(v_filtered) AS r
    OFFSET (v_page - 1) * v_size LIMIT v_size
  ) sub;

  RETURN jsonb_build_object(
    'total', v_total,
    'page', v_page,
    'size', v_size,
    'rows', coalesce(v_rows, '[]'::jsonb)
  );
END;
$function$;
