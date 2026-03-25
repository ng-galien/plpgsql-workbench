CREATE OR REPLACE FUNCTION catalog_ut.test_post_article_update()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_art catalog.article;
  v_id int;
BEGIN
  INSERT INTO catalog.article (reference, name, sale_price, vat_rate, unit)
  VALUES ('UT-MOD-01', 'To modify', 50.00, 20.00, 'u') RETURNING id INTO v_id;

  v_result := catalog.post_article_update(jsonb_build_object(
    'id', v_id, 'name', 'Modified complete', 'reference', 'UT-MOD-01',
    'sale_price', '120.00', 'purchase_price', '80.00', 'vat_rate', '10.00', 'unit', 'h'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'full update success');

  SELECT * INTO v_art FROM catalog.article WHERE id = v_id;
  RETURN NEXT is(v_art.name, 'Modified complete', 'name updated');
  RETURN NEXT is(v_art.sale_price, 120.00::numeric(12,2), 'sale_price updated');
  RETURN NEXT is(v_art.purchase_price, 80.00::numeric(12,2), 'purchase_price updated');
  RETURN NEXT is(v_art.vat_rate, 10.00::numeric(4,2), 'vat_rate updated');
  RETURN NEXT is(v_art.unit, 'h', 'unit updated');

  v_result := catalog.post_article_update(jsonb_build_object('id', v_id, 'active', 'false'));
  SELECT * INTO v_art FROM catalog.article WHERE id = v_id;
  RETURN NEXT ok(NOT v_art.active, 'article deactivated');

  v_result := catalog.post_article_update(jsonb_build_object('id', v_id, 'active', 'true'));
  SELECT * INTO v_art FROM catalog.article WHERE id = v_id;
  RETURN NEXT ok(v_art.active, 'article reactivated');

  DELETE FROM catalog.article WHERE id = v_id;
END;
$function$;
