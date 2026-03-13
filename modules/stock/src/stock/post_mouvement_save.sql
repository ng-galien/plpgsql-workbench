CREATE OR REPLACE FUNCTION stock.post_mouvement_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_type text;
  v_article_id int;
  v_depot_id int;
  v_dest_id int;
  v_qty numeric;
  v_pu numeric;
  v_art stock.article;
BEGIN
  v_type := p_data->>'type';
  v_article_id := (p_data->>'article_id')::int;
  v_depot_id := (p_data->>'depot_id')::int;
  v_dest_id := nullif(p_data->>'depot_destination_id', '')::int;
  v_qty := (p_data->>'quantite')::numeric;
  v_pu := nullif(p_data->>'prix_unitaire', '')::numeric;

  SELECT * INTO v_art FROM stock.article WHERE id = v_article_id;
  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('stock.err_article_not_found'), 'error');
  END IF;

  IF v_type = 'transfert' AND v_dest_id IS NULL THEN
    RETURN pgv.toast(pgv.t('stock.err_depot_dest_requis'), 'error');
  END IF;
  IF v_type = 'transfert' AND v_depot_id = v_dest_id THEN
    RETURN pgv.toast(pgv.t('stock.err_depot_src_dest_identiques'), 'error');
  END IF;

  IF v_type = 'sortie' THEN
    IF stock._stock_actuel(v_article_id, v_depot_id) < v_qty THEN
      RETURN pgv.toast(pgv.t('stock.err_stock_insuffisant'), 'error');
    END IF;
  END IF;

  IF v_type = 'entree' THEN
    INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, reference, notes)
    VALUES (v_article_id, v_depot_id, 'entree', v_qty, coalesce(v_pu, v_art.prix_achat), nullif(p_data->>'reference', ''), coalesce(p_data->>'notes', ''));

    PERFORM stock._recalc_pmp(v_article_id);
    IF v_pu IS NOT NULL THEN
      UPDATE stock.article SET prix_achat = v_pu WHERE id = v_article_id;
    END IF;

  ELSIF v_type = 'sortie' THEN
    INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, reference, notes)
    VALUES (v_article_id, v_depot_id, 'sortie', -v_qty, v_art.pmp, nullif(p_data->>'reference', ''), coalesce(p_data->>'notes', ''));

  ELSIF v_type = 'transfert' THEN
    IF stock._stock_actuel(v_article_id, v_depot_id) < v_qty THEN
      RETURN pgv.toast(pgv.t('stock.err_stock_insuffisant_transfert'), 'error');
    END IF;

    INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, reference, depot_destination_id, notes)
    VALUES (v_article_id, v_depot_id, 'transfert', -v_qty, v_art.pmp, nullif(p_data->>'reference', ''), v_dest_id, coalesce(p_data->>'notes', ''));

    INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, reference, depot_destination_id, notes)
    VALUES (v_article_id, v_dest_id, 'transfert', v_qty, v_art.pmp, nullif(p_data->>'reference', ''), v_depot_id, coalesce(p_data->>'notes', ''));

  ELSIF v_type = 'inventaire' THEN
    DECLARE
      v_stock_actuel numeric;
      v_ecart numeric;
    BEGIN
      v_stock_actuel := stock._stock_actuel(v_article_id, v_depot_id);
      v_ecart := v_qty - v_stock_actuel;

      IF v_ecart = 0 THEN
        RETURN pgv.toast(pgv.t('stock.toast_stock_correct'));
      END IF;

      INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, reference, notes)
      VALUES (v_article_id, v_depot_id, 'inventaire', v_ecart, v_art.pmp,
              'INV-' || to_char(now(), 'YYYYMMDD'),
              format('Inventaire: %s -> %s (écart: %s)', v_stock_actuel, v_qty, v_ecart));
    END;
  END IF;

  RETURN pgv.toast(pgv.t('stock.toast_mvt_enregistre'))
    || pgv.redirect(pgv.call_ref('get_mouvements'));
END;
$function$;
