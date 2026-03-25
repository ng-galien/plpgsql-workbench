CREATE OR REPLACE FUNCTION purchase.post_ligne_ajouter(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_commande_id int := (p_data->>'p_commande_id')::int;
  v_statut text;
  v_sort int;
BEGIN
  SELECT statut INTO v_statut FROM purchase.commande WHERE id = v_commande_id;
  IF v_statut IS NULL OR v_statut <> 'brouillon' THEN
    RETURN pgv.toast(pgv.t('purchase.err_draft_only'), 'error');
  END IF;

  SELECT coalesce(max(sort_order), 0) + 1 INTO v_sort
    FROM purchase.ligne WHERE commande_id = v_commande_id;

  -- Auto-fill price from catalog if article_id provided and no price given
  DECLARE
    v_article_id int := (p_data->>'p_article_id')::int;
    v_prix numeric := (p_data->>'p_prix_unitaire')::numeric;
  BEGIN
    IF v_article_id IS NOT NULL AND v_prix IS NULL
       AND EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                    WHERE n.nspname = 'catalog' AND c.relname = 'article') THEN
      EXECUTE format('SELECT prix_achat FROM catalog.article WHERE id = %L', v_article_id)
        INTO v_prix;
    END IF;

    INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, unite, prix_unitaire, tva_rate, article_id)
    VALUES (
      v_commande_id,
      v_sort,
      p_data->>'p_description',
      coalesce((p_data->>'p_quantite')::numeric, 1),
      coalesce(p_data->>'p_unite', 'u'),
      coalesce(v_prix, (p_data->>'p_prix_unitaire')::numeric),
      coalesce((p_data->>'p_tva_rate')::numeric, 20.00),
      v_article_id
    );
  END;

  RETURN pgv.toast(pgv.t('purchase.toast_ligne_ajoutee'))
    || pgv.redirect(pgv.call_ref('get_commande', jsonb_build_object('p_id', v_commande_id)));
END;
$function$;
