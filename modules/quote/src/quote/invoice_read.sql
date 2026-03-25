CREATE OR REPLACE FUNCTION quote.invoice_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_result jsonb;
  v_actions jsonb;
  v_status text;
  v_days int;
BEGIN
  SELECT to_jsonb(f) || jsonb_build_object(
    'client_name', c.name,
    'estimate_number', dv.number,
    'total_ht', quote._total_ht(NULL, f.id),
    'total_tva', quote._total_tva(NULL, f.id),
    'total_ttc', quote._total_ttc(NULL, f.id),
    'lines', coalesce((
      SELECT jsonb_agg(to_jsonb(l) ORDER BY l.sort_order, l.id)
      FROM quote.line_item l WHERE l.invoice_id = f.id
    ), '[]'::jsonb))
  INTO v_result
  FROM quote.invoice f
  JOIN crm.client c ON c.id = f.client_id
  LEFT JOIN quote.estimate dv ON dv.id = f.estimate_id
  WHERE f.id = p_id::int AND f.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN RETURN NULL; END IF;

  v_status := v_result->>'status';
  v_days := extract(day FROM now() - (v_result->>'created_at')::timestamptz)::int;
  v_actions := '[]'::jsonb;
  CASE v_status
    WHEN 'draft' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'send', 'uri', 'quote://invoice/' || p_id || '/send'),
        jsonb_build_object('method', 'delete', 'uri', 'quote://invoice/' || p_id));
    WHEN 'sent' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'pay', 'uri', 'quote://invoice/' || p_id || '/pay'));
      IF v_days > 30 THEN
        v_actions := v_actions || jsonb_build_array(
          jsonb_build_object('method', 'remind', 'uri', 'quote://invoice/' || p_id || '/remind'));
      END IF;
    WHEN 'overdue' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'pay', 'uri', 'quote://invoice/' || p_id || '/pay'));
    WHEN 'paid' THEN
      v_actions := '[]'::jsonb;
  END CASE;

  RETURN v_result || jsonb_build_object('actions', v_actions);
END;
$function$;
