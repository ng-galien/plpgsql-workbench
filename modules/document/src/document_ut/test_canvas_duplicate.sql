CREATE OR REPLACE FUNCTION document_ut.test_canvas_duplicate()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_src_id uuid;
  v_dup_id uuid;
  v_src_state jsonb;
  v_dup_state jsonb;
  v_src_elem_ids jsonb;
  v_dup_elem_ids jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Create source canvas with elements
  v_src_id := document.canvas_create('Original');
  PERFORM document.element_add(v_src_id, 'rect', 0, '{"x":0,"y":0,"width":100,"height":50}'::jsonb);
  PERFORM document.element_add(v_src_id, 'text', 1, '{"x":10,"y":20}'::jsonb);

  -- Duplicate
  v_dup_id := document.canvas_duplicate(v_src_id, 'Copy');

  -- Verify canvas
  v_src_state := document.canvas_get_state(v_src_id);
  v_dup_state := document.canvas_get_state(v_dup_id);

  RETURN NEXT ok(v_dup_id IS NOT NULL, 'duplicate created');
  RETURN NEXT ok(v_dup_id != v_src_id, 'different canvas ID');
  RETURN NEXT is(v_dup_state->>'name', 'Copy', 'duplicate name');
  RETURN NEXT is(v_dup_state->>'format', v_src_state->>'format', 'same format');
  RETURN NEXT ok(
    jsonb_array_length(v_dup_state->'elements') = jsonb_array_length(v_src_state->'elements'),
    'same element count'
  );

  -- Verify element IDs are different
  SELECT jsonb_agg(e->>'id') INTO v_src_elem_ids FROM jsonb_array_elements(v_src_state->'elements') e;
  SELECT jsonb_agg(e->>'id') INTO v_dup_elem_ids FROM jsonb_array_elements(v_dup_state->'elements') e;
  RETURN NEXT ok(v_src_elem_ids != v_dup_elem_ids, 'element IDs are different');

  -- Cleanup
  DELETE FROM document.canvas WHERE id IN (v_src_id, v_dup_id);
END;
$function$;
