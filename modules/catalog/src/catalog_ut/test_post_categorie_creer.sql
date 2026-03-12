CREATE OR REPLACE FUNCTION catalog_ut.test_post_categorie_creer()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_cat catalog.categorie;
  v_parent_id int;
BEGIN
  -- Create root category
  v_result := catalog.post_categorie_creer(jsonb_build_object('nom', 'UT Catégorie Root'));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create root success');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'create returns redirect');

  SELECT * INTO v_cat FROM catalog.categorie WHERE nom = 'UT Catégorie Root';
  RETURN NEXT ok(FOUND, 'root category created');
  RETURN NEXT ok(v_cat.parent_id IS NULL, 'parent_id is null for root');
  v_parent_id := v_cat.id;

  -- Create child category
  v_result := catalog.post_categorie_creer(jsonb_build_object('nom', 'UT Sous-catégorie', 'parent_id', v_parent_id::text));
  SELECT * INTO v_cat FROM catalog.categorie WHERE nom = 'UT Sous-catégorie';
  RETURN NEXT ok(FOUND, 'child category created');
  RETURN NEXT is(v_cat.parent_id, v_parent_id, 'parent_id set correctly');

  -- Cleanup
  DELETE FROM catalog.categorie WHERE nom LIKE 'UT %';
END;
$function$;
