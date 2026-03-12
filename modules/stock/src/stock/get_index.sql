CREATE OR REPLACE FUNCTION stock.get_index()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_nb_articles int;
  v_nb_alertes int;
  v_mvt_semaine int;
  v_mvt_semaine_prec int;
  v_valeur_totale numeric;
  v_body text;
  v_rows text[];
  v_variation text;
  r record;
BEGIN
  SELECT count(*)::int INTO v_nb_articles FROM stock.article WHERE active;

  -- Articles sous seuil
  SELECT count(*)::int INTO v_nb_alertes
  FROM stock.article a
  WHERE a.active AND a.seuil_mini > 0
    AND stock._stock_actuel(a.id) < a.seuil_mini;

  -- Tendance semaine
  SELECT count(*)::int INTO v_mvt_semaine
  FROM stock.mouvement
  WHERE created_at >= date_trunc('week', now());

  SELECT count(*)::int INTO v_mvt_semaine_prec
  FROM stock.mouvement
  WHERE created_at >= date_trunc('week', now()) - interval '7 days'
    AND created_at < date_trunc('week', now());

  IF v_mvt_semaine_prec > 0 THEN
    v_variation := CASE
      WHEN v_mvt_semaine > v_mvt_semaine_prec THEN '+' || round(((v_mvt_semaine - v_mvt_semaine_prec)::numeric / v_mvt_semaine_prec) * 100)::text || '%'
      WHEN v_mvt_semaine < v_mvt_semaine_prec THEN '-' || round(((v_mvt_semaine_prec - v_mvt_semaine)::numeric / v_mvt_semaine_prec) * 100)::text || '%'
      ELSE '='
    END;
  ELSE
    v_variation := NULL;
  END IF;

  -- Valeur totale du stock (quantité * PMP par article)
  SELECT coalesce(sum(stock._stock_actuel(a.id) * a.pmp), 0)
  INTO v_valeur_totale
  FROM stock.article a
  WHERE a.active AND a.pmp > 0;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Articles', v_nb_articles::text),
    pgv.stat('Valeur stock', to_char(v_valeur_totale, 'FM999G999G990D00') || ' EUR'),
    pgv.stat('Alertes', v_nb_alertes::text, CASE WHEN v_nb_alertes > 0 THEN 'danger' ELSE NULL END),
    pgv.stat('Mouvements semaine', v_mvt_semaine::text || coalesce(' (' || v_variation || ')', ''))
  ]);

  -- Alertes stock bas
  IF v_nb_alertes > 0 THEN
    v_rows := ARRAY[]::text[];
    FOR r IN
      SELECT a.id, a.reference, a.designation, a.unite, a.seuil_mini, stock._stock_actuel(a.id) AS qty
      FROM stock.article a
      WHERE a.active AND a.seuil_mini > 0
        AND stock._stock_actuel(a.id) < a.seuil_mini
      ORDER BY (stock._stock_actuel(a.id) / a.seuil_mini)
      LIMIT 10
    LOOP
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>',
          pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)),
          pgv.esc(r.designation)),
        pgv.esc(r.reference),
        pgv.badge(r.qty::text || ' ' || r.unite, 'danger'),
        r.seuil_mini::text || ' ' || r.unite
      ];
    END LOOP;
    v_body := v_body || '<h3>Stock bas</h3>' || pgv.md_table(
      ARRAY['Article', 'Réf.', 'Stock actuel', 'Seuil'],
      v_rows
    );
  END IF;

  -- Top 5 articles ce mois
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.designation, count(*) AS nb_mvt, sum(m.quantite) AS total_qty
    FROM stock.mouvement m
    JOIN stock.article a ON a.id = m.article_id
    WHERE m.created_at >= date_trunc('month', now())
    GROUP BY a.id, a.designation
    ORDER BY nb_mvt DESC
    LIMIT 5
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>',
        pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)),
        pgv.esc(r.designation)),
      r.nb_mvt::text,
      r.total_qty::text
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>Top articles ce mois</h3>' || pgv.md_table(
      ARRAY['Article', 'Mouvements', 'Qté totale'],
      v_rows
    );
  END IF;

  -- Derniers mouvements
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT m.created_at, a.designation, d.nom AS depot_nom, m.type, m.quantite, m.reference
    FROM stock.mouvement m
    JOIN stock.article a ON a.id = m.article_id
    JOIN stock.depot d ON d.id = m.depot_id
    ORDER BY m.created_at DESC
    LIMIT 10
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.created_at, 'DD/MM HH24:MI'),
      pgv.esc(r.designation),
      pgv.esc(r.depot_nom),
      pgv.badge(r.type, CASE r.type
        WHEN 'entree' THEN 'success'
        WHEN 'sortie' THEN 'danger'
        WHEN 'transfert' THEN 'info'
        WHEN 'inventaire' THEN 'warning'
      END),
      r.quantite::text,
      coalesce(r.reference, '')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucun mouvement', 'Enregistrez votre premier mouvement de stock.');
  ELSE
    v_body := v_body || '<h3>Derniers mouvements</h3>' || pgv.md_table(
      ARRAY['Date', 'Article', 'Dépôt', 'Type', 'Qté', 'Réf.'],
      v_rows
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">Nouveau mouvement</a></p>',
    pgv.call_ref('get_mouvement_form'));

  RETURN v_body;
END;
$function$;
