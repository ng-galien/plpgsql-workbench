CREATE OR REPLACE FUNCTION catalog_ut.test_post_category_create()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_cat catalog.category;
  v_parent_id int;
BEGIN
  v_result := catalog.post_category_create(jsonb_build_object('name', 'UT Category Root'));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create root success');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'create returns redirect');

  SELECT * INTO v_cat FROM catalog.category WHERE name = 'UT Category Root';
  RETURN NEXT ok(FOUND, 'root category created');
  RETURN NEXT ok(v_cat.parent_id IS NULL, 'parent_id is null for root');
  v_parent_id := v_cat.id;

  v_result := catalog.post_category_create(jsonb_build_object('name', 'UT Sub-category', 'parent_id', v_parent_id::text));
  SELECT * INTO v_cat FROM catalog.category WHERE name = 'UT Sub-category';
  RETURN NEXT ok(FOUND, 'child category created');
  RETURN NEXT is(v_cat.parent_id, v_parent_id, 'parent_id set correctly');

  DELETE FROM catalog.category WHERE name LIKE 'UT %';
END;
$function$;
