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

  v_result := stock.post_article_save(jsonb_build_object(
    'reference', 'TEST-SAVE-01', 'description', 'Article test save',
    'category', 'wood', 'unit', 'm3', 'purchase_price', '100', 'min_threshold', '5'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create returns success');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'create returns redirect');

  SELECT id INTO v_id FROM stock.article WHERE reference = 'TEST-SAVE-01' AND tenant_id = 'test';
  SELECT * INTO v_art FROM stock.article WHERE id = v_id;
  RETURN NEXT ok(FOUND, 'article created in DB');
  RETURN NEXT is(v_art.description, 'Article test save', 'designation saved');
  RETURN NEXT is(v_art.category, 'wood', 'categorie saved');
  RETURN NEXT is(v_art.unit, 'm3', 'unite saved');
  RETURN NEXT is(v_art.purchase_price, 100::numeric(12,2), 'prix_achat saved');
  RETURN NEXT is(v_art.min_threshold, 5::numeric(10,2), 'seuil_mini saved');

  v_result := stock.post_article_save(jsonb_build_object(
    'id', v_id, 'reference', 'TEST-SAVE-01', 'description', 'Article modified',
    'category', 'hardware', 'unit', 'ea', 'purchase_price', '200', 'min_threshold', '10'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'update returns success');

  SELECT * INTO v_art FROM stock.article WHERE id = v_id;
  RETURN NEXT is(v_art.description, 'Article modified', 'designation updated');
  RETURN NEXT is(v_art.category, 'hardware', 'categorie updated');
  RETURN NEXT is(v_art.purchase_price, 200::numeric(12,2), 'prix_achat updated');

  DELETE FROM stock.article WHERE tenant_id = 'test';
END;
$function$;
