CREATE OR REPLACE FUNCTION quote.post_ligne_ajouter(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_devis_id int;
  v_facture_id int;
  v_redirect text;
  v_article_id int;
  v_description text;
  v_prix_unitaire numeric;
  v_tva_rate numeric;
  v_unite text;
  v_art record;
BEGIN
  v_devis_id := (p_data->>'devis_id')::int;
  v_facture_id := (p_data->>'facture_id')::int;
  v_article_id := (p_data->>'article_id')::int;

  -- Initialize v_art to avoid "record not assigned" on field access
  SELECT NULL::text AS designation, NULL::numeric AS prix_achat, NULL::text AS unite, NULL::numeric AS tva INTO v_art;

  -- Vérifier que le parent est brouillon
  IF v_devis_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM quote.devis WHERE id = v_devis_id AND statut = 'brouillon') THEN
      RAISE EXCEPTION '%', pgv.t('quote.err_draft_lines_only');
    END IF;
    v_redirect := pgv.call_ref('get_devis', jsonb_build_object('p_id', v_devis_id));
  ELSIF v_facture_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM quote.facture WHERE id = v_facture_id AND statut = 'brouillon') THEN
      RAISE EXCEPTION '%', pgv.t('quote.err_draft_lines_only');
    END IF;
    v_redirect := pgv.call_ref('get_facture', jsonb_build_object('p_id', v_facture_id));
  ELSE
    RAISE EXCEPTION '%', pgv.t('quote.err_parent_required');
  END IF;

  -- Lookup article si sélectionné (catalog > stock)
  IF v_article_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM pg_namespace n
      JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = 'article'
     WHERE n.nspname = 'catalog'
    ) THEN
      EXECUTE
        'SELECT designation, prix_vente AS prix_achat, unite, tva
         FROM catalog.article WHERE id = $1 AND actif'
      INTO v_art USING v_article_id;
    END IF;
    IF v_art.designation IS NULL AND EXISTS (
      SELECT 1 FROM pg_namespace n
      JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = 'article'
     WHERE n.nspname = 'stock'
    ) THEN
      EXECUTE
        'SELECT designation, prix_achat, unite, NULL::numeric AS tva
         FROM stock.article WHERE id = $1 AND active = true'
      INTO v_art USING v_article_id;
    END IF;
  END IF;

  -- Resolve values: form > article > defaults
  v_description := coalesce(
    nullif(trim(p_data->>'description'), ''),
    CASE WHEN v_article_id IS NOT NULL THEN v_art.designation END,
    pgv.t('quote.err_default_description')
  );
  v_prix_unitaire := coalesce(
    nullif((p_data->>'prix_unitaire')::numeric, 0),
    CASE WHEN v_article_id IS NOT NULL THEN v_art.prix_achat END,
    0
  );
  v_unite := coalesce(
    nullif(p_data->>'unite', ''),
    CASE WHEN v_article_id IS NOT NULL THEN v_art.unite END,
    'u'
  );
  v_tva_rate := coalesce((p_data->>'tva_rate')::numeric, CASE WHEN v_article_id IS NOT NULL THEN v_art.tva END, 20.00);

  INSERT INTO quote.ligne (devis_id, facture_id, description, quantite, unite, prix_unitaire, tva_rate)
  VALUES (
    v_devis_id,
    v_facture_id,
    v_description,
    coalesce((p_data->>'quantite')::numeric, 1),
    v_unite,
    v_prix_unitaire,
    v_tva_rate
  );

  RETURN pgv.toast(pgv.t('quote.toast_ligne_added'))
    || pgv.redirect(v_redirect);
END;
$function$;
