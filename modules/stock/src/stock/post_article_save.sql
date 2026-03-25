CREATE OR REPLACE FUNCTION stock.post_article_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int;
BEGIN
  v_id := (p_data->>'id')::int;

  IF v_id IS NOT NULL AND v_id > 0 THEN
    UPDATE stock.article SET
      reference = p_data->>'reference',
      description = p_data->>'description',
      category = p_data->>'category',
      unit = p_data->>'unit',
      purchase_price = nullif(p_data->>'purchase_price', '')::numeric,
      min_threshold = coalesce(nullif(p_data->>'min_threshold', '')::numeric, 0),
      supplier_id = nullif(p_data->>'supplier_id', '')::int,
      catalog_article_id = nullif(p_data->>'catalog_article_id', '')::int,
      notes = coalesce(p_data->>'notes', '')
    WHERE id = v_id;

    RETURN pgv.toast(pgv.t('stock.toast_article_modifie'))
      || pgv.redirect(pgv.call_ref('get_article', jsonb_build_object('p_id', v_id)));
  ELSE
    INSERT INTO stock.article (reference, description, category, unit, purchase_price, min_threshold, supplier_id, catalog_article_id, notes)
    VALUES (
      p_data->>'reference',
      p_data->>'description',
      p_data->>'category',
      p_data->>'unit',
      nullif(p_data->>'purchase_price', '')::numeric,
      coalesce(nullif(p_data->>'min_threshold', '')::numeric, 0),
      nullif(p_data->>'supplier_id', '')::int,
      nullif(p_data->>'catalog_article_id', '')::int,
      coalesce(p_data->>'notes', '')
    ) RETURNING id INTO v_id;

    RETURN pgv.toast(pgv.t('stock.toast_article_cree'))
      || pgv.redirect(pgv.call_ref('get_article', jsonb_build_object('p_id', v_id)));
  END IF;
END;
$function$;
