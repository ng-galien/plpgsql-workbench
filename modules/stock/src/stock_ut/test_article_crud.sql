CREATE OR REPLACE FUNCTION stock_ut.test_article_crud()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_art stock.article;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Create
  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, tenant_id)
  VALUES ('TEST-001', 'Article test', 'bois', 'm3', 100.00, 'test')
  RETURNING id INTO v_id;

  SELECT * INTO v_art FROM stock.article WHERE id = v_id;
  RETURN NEXT ok(FOUND, 'article created');
  RETURN NEXT is(v_art.reference, 'TEST-001', 'reference matches');
  RETURN NEXT is(v_art.active, true, 'active by default');
  RETURN NEXT is(v_art.pmp, 0::numeric(12,4), 'pmp starts at 0');

  -- Update — use pg_sleep to ensure different timestamp
  PERFORM pg_sleep(0.01);
  UPDATE stock.article SET designation = 'Article modifié' WHERE id = v_id;
  SELECT * INTO v_art FROM stock.article WHERE id = v_id;
  RETURN NEXT is(v_art.designation, 'Article modifié', 'designation updated');
  RETURN NEXT ok(v_art.updated_at > v_art.created_at, 'updated_at changed');

  -- Soft delete
  UPDATE stock.article SET active = false WHERE id = v_id;
  SELECT * INTO v_art FROM stock.article WHERE id = v_id;
  RETURN NEXT is(v_art.active, false, 'soft delete works');

  -- Cleanup
  DELETE FROM stock.article WHERE tenant_id = 'test';
END;
$function$;
