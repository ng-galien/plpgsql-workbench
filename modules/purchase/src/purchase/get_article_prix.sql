CREATE OR REPLACE FUNCTION purchase.get_article_prix(p_article_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_ref text;
  v_designation text;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  -- Retrieve article info (priority: catalog > stock)
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'catalog' AND c.relname = 'article') THEN
    EXECUTE format('SELECT reference, designation FROM catalog.article WHERE id = %L', p_article_id)
      INTO v_ref, v_designation;
  ELSIF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'stock') THEN
    EXECUTE format('SELECT reference, designation FROM stock.article WHERE id = %L', p_article_id)
      INTO v_ref, v_designation;
  END IF;

  IF v_ref IS NULL THEN
    v_ref := '#' || p_article_id;
    v_designation := 'Article ' || p_article_id;
  END IF;

  v_body := '<h3>' || pgv.t('purchase.title_historique_prix') || ' — ' || pgv.esc(v_ref) || ' ' || pgv.esc(v_designation) || '</h3>';

  -- Price history: all purchase lines with this article_id, grouped by supplier
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT cl.name AS fournisseur, c.numero, l.prix_unitaire, l.unite,
           l.quantite, c.created_at,
           purchase._statut_badge(c.statut) AS badge
      FROM purchase.ligne l
      JOIN purchase.commande c ON c.id = l.commande_id
      JOIN crm.client cl ON cl.id = c.fournisseur_id
     WHERE l.article_id = p_article_id
     ORDER BY c.created_at DESC
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.fournisseur),
      pgv.esc(r.numero),
      to_char(r.prix_unitaire, 'FM999 990.00') || ' EUR/' || r.unite,
      r.quantite::text || ' ' || r.unite,
      r.badge,
      to_char(r.created_at, 'DD/MM/YYYY')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('purchase.empty_no_achat_article'));
  ELSE
    -- Stats summary
    v_body := v_body || pgv.grid(VARIADIC ARRAY[
      pgv.stat(pgv.t('purchase.stat_achats'), (array_length(v_rows, 1) / 6)::text),
      pgv.stat(pgv.t('purchase.stat_prix_min'), (SELECT to_char(min(l.prix_unitaire), 'FM999 990.00') || ' EUR'
        FROM purchase.ligne l WHERE l.article_id = p_article_id)),
      pgv.stat(pgv.t('purchase.stat_prix_max'), (SELECT to_char(max(l.prix_unitaire), 'FM999 990.00') || ' EUR'
        FROM purchase.ligne l WHERE l.article_id = p_article_id)),
      pgv.stat(pgv.t('purchase.stat_prix_moyen'), (SELECT to_char(avg(l.prix_unitaire), 'FM999 990.00') || ' EUR'
        FROM purchase.ligne l WHERE l.article_id = p_article_id))
    ]);
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('purchase.col_fournisseur'), pgv.t('purchase.col_commande'), pgv.t('purchase.col_prix_unitaire'), pgv.t('purchase.col_quantite'), pgv.t('purchase.col_statut'), pgv.t('purchase.col_date')],
      v_rows);
  END IF;

  -- Link to catalog if available
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'catalog' AND c.relname = 'article') THEN
    v_body := v_body || format('<p><a href="/catalog/article?p_id=%s">%s</a> | ', p_article_id, pgv.t('purchase.btn_voir_fiche'));
  ELSE
    v_body := v_body || '<p>';
  END IF;
  v_body := v_body || format('<a href="%s">%s</a></p>', pgv.call_ref('get_commande'), pgv.t('purchase.btn_retour_commandes'));

  RETURN v_body;
END;
$function$;
