CREATE OR REPLACE FUNCTION stock.get_article(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_art stock.article;
  v_body text;
  v_rows text[];
  v_fournisseur text;
  v_fournisseur_link text;
  v_stock_total numeric;
  v_catalog_link text;
  r record;
BEGIN
  SELECT * INTO v_art FROM stock.article WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty(pgv.t('stock.empty_article_not_found'), ''); END IF;

  SELECT name INTO v_fournisseur FROM crm.client WHERE id = v_art.fournisseur_id;
  v_stock_total := stock._stock_actuel(p_id);

  -- Fournisseur avec lien CRM
  IF v_fournisseur IS NOT NULL THEN
    v_fournisseur_link := format('<a href="/crm/client?p_id=%s">%s</a>', v_art.fournisseur_id, pgv.esc(v_fournisseur));
  ELSE
    v_fournisseur_link := '—';
  END IF;

  -- Lien catalog (cross-module, guard pg_proc)
  v_catalog_link := '—';
  IF v_art.catalog_article_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'catalog')
    AND EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'catalog' AND p.proname = 'get_article')
  THEN
    v_catalog_link := format('<a href="/catalog/article?p_id=%s">%s</a>', v_art.catalog_article_id, pgv.t('stock.cross_catalog_voir'));
  ELSIF v_art.catalog_article_id IS NOT NULL THEN
    v_catalog_link := format('#%s (%s)', v_art.catalog_article_id, pgv.t('stock.cross_catalog_unavailable'));
  END IF;

  -- Header stats
  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('stock.stat_stock_total'), v_stock_total::text || ' ' || v_art.unite),
    pgv.stat(pgv.t('stock.stat_pmp'), CASE WHEN v_art.pmp > 0 THEN to_char(v_art.pmp, 'FM999G990D00') || ' EUR' ELSE '—' END),
    pgv.stat(pgv.t('stock.stat_seuil_mini'), CASE WHEN v_art.seuil_mini > 0 THEN v_art.seuil_mini::text || ' ' || v_art.unite ELSE '—' END),
    pgv.stat(pgv.t('stock.stat_fournisseur'), v_fournisseur_link)
  ]);

  -- Info
  v_body := v_body || format('<p><strong>%s</strong> %s | <strong>%s</strong> %s | <strong>%s</strong> %s</p>',
    pgv.t('stock.label_ref'), pgv.esc(v_art.reference),
    pgv.t('stock.label_categorie'), pgv.badge(v_art.categorie, NULL),
    pgv.t('stock.label_actif'), CASE WHEN v_art.active THEN pgv.t('stock.yes') ELSE pgv.t('stock.no') END
  );

  -- Catalog link
  IF v_catalog_link <> '—' THEN
    v_body := v_body || format('<p><strong>%s</strong> %s</p>', pgv.t('stock.label_catalog'), v_catalog_link);
  END IF;

  -- Stock par dépôt
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT d.id, d.nom, stock._stock_actuel(p_id, d.id) AS qty
    FROM stock.depot d
    WHERE d.actif
      AND EXISTS (SELECT 1 FROM stock.mouvement m WHERE m.article_id = p_id AND m.depot_id = d.id)
    ORDER BY d.nom
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.nom),
      r.qty::text || ' ' || v_art.unite
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('stock.title_stock_depot') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_depot'), pgv.t('stock.col_quantite')],
      v_rows
    );
  END IF;

  -- Derniers mouvements
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT m.created_at, d.nom AS depot_nom, m.type, m.quantite, m.prix_unitaire, m.reference
    FROM stock.mouvement m
    JOIN stock.depot d ON d.id = m.depot_id
    WHERE m.article_id = p_id
    ORDER BY m.created_at DESC
    LIMIT 20
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.created_at, 'DD/MM HH24:MI'),
      pgv.esc(r.depot_nom),
      pgv.badge(r.type, CASE r.type
        WHEN 'entree' THEN 'success'
        WHEN 'sortie' THEN 'danger'
        WHEN 'transfert' THEN 'info'
        WHEN 'inventaire' THEN 'warning'
      END),
      r.quantite::text,
      CASE WHEN r.prix_unitaire IS NOT NULL THEN to_char(r.prix_unitaire, 'FM999G990D00') ELSE '—' END,
      coalesce(r.reference, '')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('stock.title_mvt_recents') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_date'), pgv.t('stock.col_depot'), pgv.t('stock.col_type'), pgv.t('stock.col_qty'), pgv.t('stock.col_pu'), pgv.t('stock.col_ref')],
      v_rows, 10
    );
  END IF;

  -- Actions
  v_body := v_body || format('<p><a href="%s" role="button">%s</a> ',
    pgv.call_ref('get_article_form', jsonb_build_object('p_id', p_id)), pgv.t('stock.btn_modifier'));
  v_body := v_body || pgv.action('post_article_delete', pgv.t('stock.btn_desactiver'),
    jsonb_build_object('id', p_id), pgv.t('stock.confirm_desactiver')) || '</p>';

  RETURN v_body;
END;
$function$;
