CREATE OR REPLACE FUNCTION stock_ut.test_post_article_save()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_art stock.article;
  v_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Create
  v_result := stock.post_article_save(jsonb_build_object(
    'reference', 'TEST-SAVE-01', 'designation', 'Article test save',
    'categorie', 'bois', 'unite', 'm3', 'prix_achat', '100', 'seuil_mini', '5'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create returns success');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'create returns redirect');

  SELECT id INTO v_id FROM stock.article WHERE reference = 'TEST-SAVE-01' AND tenant_id = 'test';
  SELECT * INTO v_art FROM stock.article WHERE id = v_id;
  RETURN NEXT ok(FOUND, 'article created in DB');
  RETURN NEXT is(v_art.designation, 'Article test save', 'designation saved');
  RETURN NEXT is(v_art.categorie, 'bois', 'categorie saved');
  RETURN NEXT is(v_art.unite, 'm3', 'unite saved');
  RETURN NEXT is(v_art.prix_achat, 100::numeric(12,2), 'prix_achat saved');
  RETURN NEXT is(v_art.seuil_mini, 5::numeric(10,2), 'seuil_mini saved');

  -- Update
  v_result := stock.post_article_save(jsonb_build_object(
    'id', v_id, 'reference', 'TEST-SAVE-01', 'designation', 'Article modifié',
    'categorie', 'quincaillerie', 'unite', 'u', 'prix_achat', '200', 'seuil_mini', '10'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'update returns success');

  SELECT * INTO v_art FROM stock.article WHERE id = v_id;
  RETURN NEXT is(v_art.designation, 'Article modifié', 'designation updated');
  RETURN NEXT is(v_art.categorie, 'quincaillerie', 'categorie updated');
  RETURN NEXT is(v_art.prix_achat, 200::numeric(12,2), 'prix_achat updated');

  -- Cleanup
  DELETE FROM stock.article WHERE tenant_id = 'test';
END;
$function$;
