CREATE OR REPLACE FUNCTION purchase.post_line_add(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_order_id int := (p_data->>'p_commande_id')::int;
  v_status text;
  v_sort int;
BEGIN
  SELECT status INTO v_status FROM purchase.purchase_order WHERE id = v_order_id;
  IF v_status IS NULL OR v_status <> 'draft' THEN
    RETURN pgv.toast(pgv.t('purchase.err_draft_only'), 'error');
  END IF;

  SELECT coalesce(max(sort_order), 0) + 1 INTO v_sort
    FROM purchase.order_line WHERE order_id = v_order_id;

  DECLARE
    v_article_id int := (p_data->>'p_article_id')::int;
    v_price numeric := (p_data->>'p_prix_unitaire')::numeric;
  BEGIN
    IF v_article_id IS NOT NULL AND v_price IS NULL
       AND EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                    WHERE n.nspname = 'catalog' AND c.relname = 'article') THEN
      EXECUTE format('SELECT prix_achat FROM catalog.article WHERE id = %L', v_article_id)
        INTO v_price;
    END IF;

    INSERT INTO purchase.order_line (order_id, sort_order, description, quantity, unit, unit_price, tva_rate, article_id)
    VALUES (
      v_order_id,
      v_sort,
      p_data->>'p_description',
      coalesce((p_data->>'p_quantite')::numeric, 1),
      coalesce(p_data->>'p_unite', 'u'),
      coalesce(v_price, (p_data->>'p_prix_unitaire')::numeric),
      coalesce((p_data->>'p_tva_rate')::numeric, 20.00),
      v_article_id
    );
  END;

  RETURN pgv.toast(pgv.t('purchase.toast_line_added'))
    || pgv.redirect(pgv.call_ref('get_order', jsonb_build_object('p_id', v_order_id)));
END;
$function$;
