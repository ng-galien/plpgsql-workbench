CREATE OR REPLACE FUNCTION sdui_ut.test_ui_tier1()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v jsonb;
BEGIN
  -- ui_timeline
  v := sdui.ui_timeline('[{"date":"2026-03-12","label":"Created","variant":"info"},{"date":"2026-03-13","label":"Sent"}]'::jsonb);
  RETURN NEXT is(v->>'type', 'timeline', 'timeline: type');
  RETURN NEXT is(jsonb_array_length(v->'events'), 2, 'timeline: 2 events');
  RETURN NEXT is(v->'events'->0->>'label', 'Created', 'timeline: first event label');
  RETURN NEXT is(v->'events'->0->>'variant', 'info', 'timeline: first event variant');

  -- ui_currency
  v := sdui.ui_currency(5200.50);
  RETURN NEXT is(v->>'type', 'currency', 'currency: type');
  RETURN NEXT ok((v->>'amount')::numeric = 5200.50, 'currency: amount');
  RETURN NEXT is(v->>'currency', 'EUR', 'currency: default EUR');

  v := sdui.ui_currency(-100, 'USD');
  RETURN NEXT is(v->>'currency', 'USD', 'currency: custom currency');
  RETURN NEXT ok((v->>'amount')::numeric = -100, 'currency: negative');

  -- ui_workflow
  v := sdui.ui_workflow(ARRAY['draft','sent','accepted'], 'sent');
  RETURN NEXT is(v->>'type', 'workflow', 'workflow: type');
  RETURN NEXT is(v->>'current', 'sent', 'workflow: current state');
  RETURN NEXT is(jsonb_array_length(v->'states'), 3, 'workflow: 3 states');
  RETURN NEXT is(v->'states'->>0, 'draft', 'workflow: first state');

  -- ui_line_items
  v := sdui.ui_line_items('lines', '[{"key":"desc","label":"Description"},{"key":"qty","label":"Qty"}]'::jsonb);
  RETURN NEXT is(v->>'type', 'line_items', 'line_items: type');
  RETURN NEXT is(v->>'source', 'lines', 'line_items: source');
  RETURN NEXT is(jsonb_array_length(v->'columns'), 2, 'line_items: 2 columns');
  RETURN NEXT ok(v->'totals' IS NULL, 'line_items: no totals by default');

  v := sdui.ui_line_items('lines', '[]'::jsonb, '{"ht":1017.50,"tva":124.50,"ttc":1142.00}'::jsonb);
  RETURN NEXT ok((v->'totals'->>'ttc')::numeric = 1142.00, 'line_items: totals ttc');
END;
$function$;
