CREATE OR REPLACE FUNCTION pgv_ut.test_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_schema json;
BEGIN
  v_schema := pgv.view_schema();
  RETURN NEXT ok(v_schema IS NOT NULL, 'view_schema returns json');

  -- String-only fields (retrocompat)
  RETURN NEXT ok(
    jsonb_matches_schema(v_schema, '{"uri":"test://entity","label":"test.label","template":{"compact":{"fields":["name","email"]},"standard":{"fields":["name"]}}}'::jsonb),
    'string fields validate'
  );

  -- Object fields with type
  RETURN NEXT ok(
    jsonb_matches_schema(v_schema, '{"uri":"test://entity","label":"test.label","template":{"compact":{"fields":[{"key":"date","type":"date"},{"key":"amount","type":"currency","label":"test.amount"}]},"standard":{"fields":["name"]}}}'::jsonb),
    'object fields with type validate'
  );

  -- Mixed string + object fields
  RETURN NEXT ok(
    jsonb_matches_schema(v_schema, '{"uri":"test://entity","label":"test.label","template":{"compact":{"fields":["name",{"key":"created","type":"datetime"}]},"standard":{"fields":["name"]}}}'::jsonb),
    'mixed string + object fields validate'
  );

  -- Existing charter_view still passes
  RETURN NEXT ok(
    jsonb_matches_schema(v_schema, docs.charter_view()),
    'docs.charter_view() passes validation'
  );
END;
$function$;
