CREATE OR REPLACE FUNCTION pgv_ut.test_table()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v text;
  v_config jsonb;
BEGIN
  -- Minimal config
  v_config := '{"rpc":"data_test","schema":"test","cols":[{"key":"id","label":"#"}]}'::jsonb;
  v := pgv.table(v_config);
  RETURN NEXT ok(v LIKE '%x-data="pgvTable"%', 'has Alpine pgvTable directive');
  RETURN NEXT ok(v LIKE '%data-config=%', 'has data-config attribute');
  RETURN NEXT ok(v LIKE '%data_test%', 'config contains rpc name');
  RETURN NEXT ok(v LIKE '%<div %', 'wrapper is div');

  -- Config with filters
  v_config := jsonb_build_object(
    'rpc', 'data_items',
    'schema', 'myapp',
    'page_size', 15,
    'filters', jsonb_build_array(
      jsonb_build_object('name', 'p_status', 'type', 'select', 'label', 'Statut',
        'options', jsonb_build_array(jsonb_build_array('', 'Tous'), jsonb_build_array('active', 'Actif'))),
      jsonb_build_object('name', 'q', 'type', 'search', 'label', 'Recherche')),
    'cols', jsonb_build_array(
      jsonb_build_object('key', 'id', 'label', '#'),
      jsonb_build_object('key', 'name', 'label', 'Nom'),
      jsonb_build_object('key', 'status', 'label', 'Statut', 'class', 'pgv-col-badge'))
  );
  v := pgv.table(v_config);
  RETURN NEXT ok(v LIKE '%data_items%', 'config contains rpc');
  RETURN NEXT ok(v LIKE '%myapp%', 'config contains schema');
  RETURN NEXT ok(v LIKE '%page_size%', 'config contains page_size');
  RETURN NEXT ok(v LIKE '%p_status%', 'config contains filter name');
  RETURN NEXT ok(v LIKE '%pgv-col-badge%', 'config contains column class');
  RETURN NEXT ok(v LIKE '%Recherche%', 'config contains search label');

  -- HTML escaping
  v_config := '{"rpc":"test","schema":"s","cols":[{"key":"x","label":"A&B"}]}'::jsonb;
  v := pgv.table(v_config);
  RETURN NEXT ok(v LIKE '%A&amp;B%', 'label is HTML-escaped in attribute');

  -- No inline styles
  RETURN NEXT ok(v NOT LIKE '%style=%', 'no inline styles');
END;
$function$;
