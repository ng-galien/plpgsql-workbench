CREATE OR REPLACE FUNCTION stock.post_inventaire_valider(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_depot_id int := (p_data->>'p_depot_id')::int;
  v_key text;
  v_val text;
  v_article_id int;
  v_qty_reelle numeric;
  v_qty_theorique numeric;
  v_ecart numeric;
  v_nb_ajustements int := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM stock.depot WHERE id = v_depot_id AND actif) THEN
    RETURN pgv.toast(pgv.t('stock.err_depot_not_found'), 'error');
  END IF;

  FOR v_key, v_val IN SELECT key, value FROM jsonb_each_text(p_data) WHERE key LIKE 'qty_%'
  LOOP
    v_article_id := replace(v_key, 'qty_', '')::int;
    v_qty_reelle := v_val::numeric;
    v_qty_theorique := stock._stock_actuel(v_article_id, v_depot_id);
    v_ecart := v_qty_reelle - v_qty_theorique;

    IF v_ecart = 0 THEN
      CONTINUE;
    END IF;

    INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, reference)
    VALUES (v_article_id, v_depot_id, 'inventaire', v_ecart,
            'INV-' || to_char(now(), 'YYYYMMDD'));

    v_nb_ajustements := v_nb_ajustements + 1;
  END LOOP;

  IF v_nb_ajustements = 0 THEN
    RETURN pgv.toast(pgv.t('stock.toast_stock_conforme'))
      || pgv.redirect(pgv.call_ref('get_inventaire', jsonb_build_object('p_depot_id', v_depot_id)));
  END IF;

  RETURN pgv.toast(format(pgv.t('stock.toast_inventaire_valide'), v_nb_ajustements))
    || pgv.redirect(pgv.call_ref('get_depot', jsonb_build_object('p_id', v_depot_id)));
END;
$function$;
