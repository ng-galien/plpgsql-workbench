CREATE OR REPLACE FUNCTION quote.estimate_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_result jsonb;
  v_actions jsonb;
  v_status text;
BEGIN
  SELECT to_jsonb(d) || jsonb_build_object(
    'client_name', c.name,
    'total_ht', quote._total_ht(d.id, NULL),
    'total_tva', quote._total_tva(d.id, NULL),
    'total_ttc', quote._total_ttc(d.id, NULL),
    'lines', coalesce((
      SELECT jsonb_agg(to_jsonb(l) ORDER BY l.sort_order, l.id)
      FROM quote.line_item l WHERE l.estimate_id = d.id
    ), '[]'::jsonb))
  INTO v_result
  FROM quote.estimate d
  JOIN crm.client c ON c.id = d.client_id
  WHERE d.id = p_id::int AND d.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN RETURN NULL; END IF;

  v_status := v_result->>'status';
  v_actions := '[]'::jsonb;
  CASE v_status
    WHEN 'draft' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'send', 'uri', 'quote://estimate/' || p_id || '/send'),
        jsonb_build_object('method', 'duplicate', 'uri', 'quote://estimate/' || p_id || '/duplicate'),
        jsonb_build_object('method', 'delete', 'uri', 'quote://estimate/' || p_id));
    WHEN 'sent' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'accept', 'uri', 'quote://estimate/' || p_id || '/accept'),
        jsonb_build_object('method', 'decline', 'uri', 'quote://estimate/' || p_id || '/decline'),
        jsonb_build_object('method', 'duplicate', 'uri', 'quote://estimate/' || p_id || '/duplicate'));
    WHEN 'accepted' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'invoice', 'uri', 'quote://estimate/' || p_id || '/invoice'),
        jsonb_build_object('method', 'duplicate', 'uri', 'quote://estimate/' || p_id || '/duplicate'));
    WHEN 'declined' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'duplicate', 'uri', 'quote://estimate/' || p_id || '/duplicate'));
  END CASE;

  RETURN v_result || jsonb_build_object('actions', v_actions);
END;
$function$;
