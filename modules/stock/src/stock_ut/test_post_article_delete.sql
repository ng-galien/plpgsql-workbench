CREATE OR REPLACE FUNCTION stock_ut.test_post_article_delete()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_result text;
  v_art stock.article;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  INSERT INTO stock.article (reference, designation, categorie, tenant_id)
  VALUES ('TEST-DEL-01', 'À désactiver', 'bois', 'test')
  RETURNING id INTO v_id;

  v_result := stock.post_article_delete(jsonb_build_object('id', v_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'delete returns success');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'delete returns redirect');

  SELECT * INTO v_art FROM stock.article WHERE id = v_id;
  RETURN NEXT is(v_art.active, false, 'article soft-deleted');

  -- Cleanup
  DELETE FROM stock.article WHERE tenant_id = 'test';
END;
$function$;
