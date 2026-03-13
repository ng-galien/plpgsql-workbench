CREATE OR REPLACE FUNCTION pgv_qa.data_products(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  -- Business filters
  v_status   text := p_params->>'p_status';
  v_category text := p_params->>'p_category';
  -- Search
  v_q        text := p_params->>'q';
  -- Meta
  v_page     int  := coalesce((p_params->>'_page')::int, 1);
  v_size     int  := coalesce((p_params->>'_size')::int, 20);
  -- Result
  v_total    int;
  v_rows     jsonb;
BEGIN
  -- Count
  SELECT count(*) INTO v_total
  FROM pgv_qa.product t
  WHERE (v_status IS NULL OR t.status = v_status)
    AND (v_category IS NULL OR t.category = v_category)
    AND (v_q IS NULL OR t.search_vec @@ plainto_tsquery('pgv_search', v_q));

  -- Rows (paginated)
  SELECT coalesce(jsonb_agg(row), '[]') INTO v_rows
  FROM (
    SELECT jsonb_build_array(t.id, t.name, t.category, t.price, t.status) AS row
    FROM pgv_qa.product t
    WHERE (v_status IS NULL OR t.status = v_status)
      AND (v_category IS NULL OR t.category = v_category)
      AND (v_q IS NULL OR t.search_vec @@ plainto_tsquery('pgv_search', v_q))
    ORDER BY t.id
    LIMIT v_size OFFSET (v_page - 1) * v_size
  ) sub;

  RETURN jsonb_build_object(
    'total', v_total,
    'page',  v_page,
    'size',  v_size,
    'rows',  v_rows
  );
END;
$function$;
