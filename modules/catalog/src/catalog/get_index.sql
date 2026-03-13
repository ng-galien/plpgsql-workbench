CREATE OR REPLACE FUNCTION catalog.get_index(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_nb_articles int;
  v_nb_categories int;
  v_prix_moyen numeric;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  SELECT count(*)::int INTO v_nb_articles FROM catalog.article WHERE actif;
  SELECT count(*)::int INTO v_nb_categories FROM catalog.categorie;
  SELECT coalesce(round(avg(prix_vente), 2), 0) INTO v_prix_moyen
  FROM catalog.article WHERE actif AND prix_vente IS NOT NULL;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('catalog.stat_articles_actifs'), v_nb_articles::text),
    pgv.stat(pgv.t('catalog.stat_categories'), v_nb_categories::text),
    pgv.stat(pgv.t('catalog.stat_prix_moyen'), to_char(v_prix_moyen, 'FM999G990D00') || ' EUR HT')
  ]);

  -- Articles récents
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.designation, c.nom AS categorie,
           a.prix_vente, a.unite, a.actif
    FROM catalog.article a
    LEFT JOIN catalog.categorie c ON c.id = a.categorie_id
    ORDER BY a.created_at DESC
    LIMIT 10
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>',
        pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)),
        pgv.esc(coalesce(r.reference, '#' || r.id))),
      pgv.esc(r.designation),
      coalesce(pgv.badge(r.categorie), '—'),
      CASE WHEN r.prix_vente IS NOT NULL
        THEN to_char(r.prix_vente, 'FM999G990D00') || ' EUR'
        ELSE '—' END,
      r.unite,
      CASE WHEN r.actif THEN pgv.badge(pgv.t('catalog.badge_actif'), 'success') ELSE pgv.badge(pgv.t('catalog.badge_inactif'), 'warning') END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('catalog.empty_no_article'), pgv.t('catalog.empty_first_article'));
  ELSE
    v_body := v_body || '<h3>' || pgv.t('catalog.title_recent') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('catalog.col_ref'), pgv.t('catalog.col_designation'), pgv.t('catalog.col_categorie'), pgv.t('catalog.col_prix_vente'), pgv.t('catalog.col_unite'), pgv.t('catalog.col_statut')],
      v_rows
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">%s</a></p>',
    pgv.call_ref('get_article_form'), pgv.t('catalog.btn_new_article'));

  RETURN v_body;
END;
$function$;
