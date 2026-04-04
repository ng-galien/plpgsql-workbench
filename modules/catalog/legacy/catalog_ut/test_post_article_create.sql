CREATE OR REPLACE FUNCTION catalog_ut.test_post_article_create()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_art catalog.article;
BEGIN
  v_result := catalog.post_article_create(jsonb_build_object(
    'reference', 'UT-ART-01', 'name', 'Article test UT',
    'sale_price', '100.00', 'purchase_price', '60.00', 'vat_rate', '20.00', 'unit', 'u'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create returns success toast');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'create returns redirect');

  SELECT * INTO v_art FROM catalog.article WHERE reference = 'UT-ART-01';
  RETURN NEXT ok(FOUND, 'article created in DB');
  RETURN NEXT is(v_art.name, 'Article test UT', 'name saved');
  RETURN NEXT is(v_art.sale_price, 100.00::numeric(12,2), 'sale_price saved');
  RETURN NEXT is(v_art.purchase_price, 60.00::numeric(12,2), 'purchase_price saved');
  RETURN NEXT is(v_art.vat_rate, 20.00::numeric(4,2), 'vat_rate saved');
  RETURN NEXT is(v_art.unit, 'u', 'unit saved');
  RETURN NEXT ok(v_art.active, 'article active by default');

  DELETE FROM catalog.article WHERE reference = 'UT-ART-01';
END;
$function$;
