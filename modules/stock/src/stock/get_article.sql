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
  r record;
BEGIN
  SELECT * INTO v_art FROM stock.article WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty('Article introuvable', ''); END IF;

  SELECT name INTO v_fournisseur FROM crm.client WHERE id = v_art.fournisseur_id;
  v_stock_total := stock._stock_actuel(p_id);

  -- Fournisseur avec lien CRM
  IF v_fournisseur IS NOT NULL THEN
    v_fournisseur_link := format('<a href="/crm/client?p_id=%s">%s</a>', v_art.fournisseur_id, pgv.esc(v_fournisseur));
  ELSE
    v_fournisseur_link := '—';
  END IF;

  -- Header stats
  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Stock total', v_stock_total::text || ' ' || v_art.unite),
    pgv.stat('PMP', CASE WHEN v_art.pmp > 0 THEN to_char(v_art.pmp, 'FM999G990D00') || ' EUR' ELSE '—' END),
    pgv.stat('Seuil mini', CASE WHEN v_art.seuil_mini > 0 THEN v_art.seuil_mini::text || ' ' || v_art.unite ELSE '—' END),
    pgv.stat('Fournisseur', v_fournisseur_link)
  ]);

  -- Info
  v_body := v_body || format('<p><strong>Réf:</strong> %s | <strong>Catégorie:</strong> %s | <strong>Actif:</strong> %s</p>',
    pgv.esc(v_art.reference),
    pgv.badge(v_art.categorie, NULL),
    CASE WHEN v_art.active THEN 'Oui' ELSE 'Non' END
  );

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
    v_body := v_body || '<h3>Stock par dépôt</h3>' || pgv.md_table(
      ARRAY['Dépôt', 'Quantité'],
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
    v_body := v_body || '<h3>Mouvements récents</h3>' || pgv.md_table(
      ARRAY['Date', 'Dépôt', 'Type', 'Qté', 'PU', 'Réf.'],
      v_rows, 10
    );
  END IF;

  -- Actions
  v_body := v_body || format('<p><a href="%s" role="button">Modifier</a> ',
    pgv.call_ref('get_article_form', jsonb_build_object('p_id', p_id)));
  v_body := v_body || pgv.action('Désactiver', 'post_article_delete',
    jsonb_build_object('id', p_id), 'Désactiver cet article ?') || '</p>';

  RETURN v_body;
END;
$function$;
