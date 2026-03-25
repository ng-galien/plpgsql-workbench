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
      designation = p_data->>'designation',
      categorie = p_data->>'categorie',
      unite = p_data->>'unite',
      prix_achat = nullif(p_data->>'prix_achat', '')::numeric,
      seuil_mini = coalesce(nullif(p_data->>'seuil_mini', '')::numeric, 0),
      fournisseur_id = nullif(p_data->>'fournisseur_id', '')::int,
      catalog_article_id = nullif(p_data->>'catalog_article_id', '')::int,
      notes = coalesce(p_data->>'notes', '')
    WHERE id = v_id;

    RETURN pgv.toast(pgv.t('stock.toast_article_modifie'))
      || pgv.redirect(pgv.call_ref('get_article', jsonb_build_object('p_id', v_id)));
  ELSE
    INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, seuil_mini, fournisseur_id, catalog_article_id, notes)
    VALUES (
      p_data->>'reference',
      p_data->>'designation',
      p_data->>'categorie',
      p_data->>'unite',
      nullif(p_data->>'prix_achat', '')::numeric,
      coalesce(nullif(p_data->>'seuil_mini', '')::numeric, 0),
      nullif(p_data->>'fournisseur_id', '')::int,
      nullif(p_data->>'catalog_article_id', '')::int,
      coalesce(p_data->>'notes', '')
    ) RETURNING id INTO v_id;

    RETURN pgv.toast(pgv.t('stock.toast_article_cree'))
      || pgv.redirect(pgv.call_ref('get_article', jsonb_build_object('p_id', v_id)));
  END IF;
END;
$function$;
