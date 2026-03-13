CREATE OR REPLACE FUNCTION stock.get_valorisation()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text;
  v_valeur_totale numeric;
  v_nb_articles int;
  v_nb_alertes int;
  v_rows text[];
  r record;
BEGIN
  -- Stats globales
  SELECT count(*)::int INTO v_nb_articles FROM stock.article WHERE active;

  SELECT coalesce(sum(stock._stock_actuel(a.id) * a.pmp), 0)
  INTO v_valeur_totale
  FROM stock.article a WHERE a.active AND a.pmp > 0;

  SELECT count(*)::int INTO v_nb_alertes
  FROM stock.article a
  WHERE a.active AND a.seuil_mini > 0
    AND stock._stock_actuel(a.id) < a.seuil_mini;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('stock.stat_valeur_totale'), to_char(v_valeur_totale, 'FM999G999G990D00') || ' EUR'),
    pgv.stat(pgv.t('stock.stat_articles_stock'), v_nb_articles::text),
    pgv.stat(pgv.t('stock.stat_en_alerte'), v_nb_alertes::text, CASE WHEN v_nb_alertes > 0 THEN 'danger' ELSE NULL END)
  ]);

  -- Valorisation par dépôt
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT d.nom AS depot_nom, d.type AS depot_type,
           count(DISTINCT m.article_id)::int AS nb_articles,
           coalesce(sum(m.quantite * a.pmp), 0) AS valeur
    FROM stock.depot d
    LEFT JOIN stock.mouvement m ON m.depot_id = d.id
    LEFT JOIN stock.article a ON a.id = m.article_id AND a.active
    WHERE d.actif
    GROUP BY d.id, d.nom, d.type
    ORDER BY valeur DESC
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.depot_nom),
      pgv.badge(r.depot_type, CASE r.depot_type
        WHEN 'entrepot' THEN 'info'
        WHEN 'atelier' THEN 'success'
        WHEN 'chantier' THEN 'warning'
        WHEN 'vehicule' THEN 'primary'
      END),
      r.nb_articles::text,
      to_char(r.valeur, 'FM999G999G990D00') || ' EUR'
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('stock.title_par_depot') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_depot'), pgv.t('stock.col_type'), pgv.t('stock.col_articles'), pgv.t('stock.col_valeur')],
      v_rows
    );
  END IF;

  -- Valorisation par catégorie
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.categorie,
           count(*)::int AS nb_articles,
           coalesce(sum(stock._stock_actuel(a.id) * a.pmp), 0) AS valeur
    FROM stock.article a
    WHERE a.active AND a.pmp > 0
    GROUP BY a.categorie
    ORDER BY valeur DESC
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.badge(r.categorie, CASE r.categorie
        WHEN 'bois' THEN 'success'
        WHEN 'quincaillerie' THEN 'info'
        WHEN 'panneau' THEN 'warning'
        WHEN 'isolant' THEN 'primary'
        WHEN 'finition' THEN 'default'
        ELSE NULL
      END),
      r.nb_articles::text,
      to_char(r.valeur, 'FM999G999G990D00') || ' EUR'
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('stock.title_par_categorie') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_categorie'), pgv.t('stock.col_articles'), pgv.t('stock.col_valeur')],
      v_rows
    );
  END IF;

  RETURN v_body;
END;
$function$;
