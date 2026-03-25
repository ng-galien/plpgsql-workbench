CREATE OR REPLACE FUNCTION stock.entree_reception(p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_depot_id int := (p_data->>'depot_id')::int;
  v_ref text := coalesce(p_data->>'reception_ref', 'RECEPTION');
  v_lignes jsonb := p_data->'lignes';
  v_ligne jsonb;
  v_article_id int;
  v_quantite numeric;
  v_prix numeric;
  v_nb_articles int := 0;
  v_total_qty numeric := 0;
  v_total_valeur numeric := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM stock.depot WHERE id = v_depot_id AND actif) THEN
    RETURN jsonb_build_object('ok', false, 'error', pgv.t('stock.err_depot_inactive'));
  END IF;

  IF v_lignes IS NULL OR jsonb_array_length(v_lignes) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', pgv.t('stock.err_no_lignes'));
  END IF;

  FOR i IN 0 .. jsonb_array_length(v_lignes) - 1 LOOP
    v_ligne := v_lignes->i;
    v_article_id := (v_ligne->>'article_id')::int;
    v_quantite := (v_ligne->>'quantite')::numeric;
    v_prix := (v_ligne->>'prix_unitaire')::numeric;

    IF NOT EXISTS (SELECT 1 FROM stock.article WHERE id = v_article_id AND active) THEN
      CONTINUE;
    END IF;

    IF v_quantite IS NULL OR v_quantite <= 0 THEN
      CONTINUE;
    END IF;

    INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, reference)
    VALUES (v_article_id, v_depot_id, 'entree', v_quantite, v_prix, v_ref);

    PERFORM stock._recalc_pmp(v_article_id);

    IF v_prix IS NOT NULL THEN
      UPDATE stock.article SET prix_achat = v_prix WHERE id = v_article_id;
    END IF;

    v_nb_articles := v_nb_articles + 1;
    v_total_qty := v_total_qty + v_quantite;
    v_total_valeur := v_total_valeur + coalesce(v_quantite * v_prix, 0);
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'nb_articles', v_nb_articles,
    'total_quantite', v_total_qty,
    'total_valeur', round(v_total_valeur, 2),
    'depot_id', v_depot_id,
    'reference', v_ref
  );
END;
$function$;
