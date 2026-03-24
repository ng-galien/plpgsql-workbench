CREATE OR REPLACE FUNCTION pgv_ut.test_ui_form_for()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v jsonb;
  f jsonb;
BEGIN
  v := pgv.ui_form_for('docs', 'charte');

  -- Structure
  RETURN NEXT is(v->>'type', 'form', 'type is form');
  RETURN NEXT is(v->>'uri', 'docs://charte', 'uri is docs://charte');
  RETURN NEXT is(v->>'verb', 'set', 'default verb is set');
  RETURN NEXT ok(jsonb_array_length(v->'fields') > 5, 'has multiple fields');

  -- Text column → text field
  SELECT item INTO f FROM jsonb_array_elements(v->'fields') item WHERE item->>'key' = 'name';
  RETURN NEXT is(f->>'fieldType', 'text', 'text column → text field');
  RETURN NEXT is((f->>'required')::bool, true, 'NOT NULL → required');

  -- Excluded columns
  RETURN NEXT ok(
    NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v->'fields') item WHERE item->>'key' = 'id'),
    'id excluded'
  );
  RETURN NEXT ok(
    NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v->'fields') item WHERE item->>'key' = 'tenant_id'),
    'tenant_id excluded'
  );

  -- COMMENT ON → label
  SELECT item INTO f FROM jsonb_array_elements(v->'fields') item WHERE item->>'key' = 'color_bg';
  RETURN NEXT ok(f->>'label' != 'color bg', 'COMMENT ON used as label (not column name)');

  -- jsonb → textarea
  SELECT item INTO f FROM jsonb_array_elements(v->'fields') item WHERE item->>'key' = 'rules';
  RETURN NEXT is(f->>'fieldType', 'textarea', 'jsonb → textarea');

  -- Document: FK → select, numeric → number
  v := pgv.ui_form_for('docs', 'document');
  SELECT item INTO f FROM jsonb_array_elements(v->'fields') item WHERE item->>'key' = 'charte_id';
  RETURN NEXT is(f->>'fieldType', 'select', 'FK → select');
  RETURN NEXT ok(f->'options'->>'source' LIKE '%://charte', 'FK select has source');

  SELECT item INTO f FROM jsonb_array_elements(v->'fields') item WHERE item->>'key' = 'width';
  RETURN NEXT is(f->>'fieldType', 'number', 'numeric → number');

  -- Verb override
  v := pgv.ui_form_for('docs', 'charte', 'patch');
  RETURN NEXT is(v->>'verb', 'patch', 'verb override works');
END;
$function$;
