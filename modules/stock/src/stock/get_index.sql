CREATE OR REPLACE FUNCTION stock.get_index()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_nb_articles int;
  v_nb_depots int;
  v_nb_alertes int;
  v_nb_mouvements_mois int;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  SELECT count(*)::int INTO v_nb_articles FROM stock.article WHERE active;
  SELECT count(*)::int INTO v_nb_depots FROM stock.depot WHERE actif;

  -- Articles sous seuil
  SELECT count(*)::int INTO v_nb_alertes
  FROM stock.article a
  WHERE a.active AND a.seuil_mini > 0
    AND stock._stock_actuel(a.id) < a.seuil_mini;

  SELECT count(*)::int INTO v_nb_mouvements_mois
  FROM stock.mouvement
  WHERE created_at >= date_trunc('month', now());

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Articles', v_nb_articles::text),
    pgv.stat('Dépôts', v_nb_depots::text),
    pgv.stat('Alertes', v_nb_alertes::text, CASE WHEN v_nb_alertes > 0 THEN 'danger' ELSE NULL END),
    pgv.stat('Mouvements ce mois', v_nb_mouvements_mois::text)
  ]);

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
