CREATE OR REPLACE FUNCTION sdui_ut.test_ui_node_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_schema json;
BEGIN
  v_schema := sdui.ui_node_schema();
  RETURN NEXT ok(v_schema IS NOT NULL, 'ui_node_schema returns json');

  RETURN NEXT ok(
    jsonb_matches_schema(
      v_schema,
      '{"type":"column","children":[{"type":"text","value":"hello"},{"type":"action","label":"demo.action_save","verb":"set","uri":"demo://note/1","variant":"primary"}]}'::jsonb
    ),
    'basic ui node tree validates'
  );

  RETURN NEXT ok(
    jsonb_matches_schema(
      v_schema,
      '{"type":"field","field":{"key":"client_id","type":"select","label":"demo.field_client","search":true,"source":"crm://client","display":"name"}}'::jsonb
    ),
    'field node with searchable select validates'
  );
END;
$function$;
