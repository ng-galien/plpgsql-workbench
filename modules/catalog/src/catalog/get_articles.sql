CREATE OR REPLACE FUNCTION catalog.get_articles(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_q text := p_params->>'q';
  v_categorie_id int := nullif(p_params->>'categorie_id', '')::int;
  v_actif text := coalesce(p_params->>'actif', 'tous');
  v_body text;
  v_rows text[];
  v_cat_options text;
  r record;
BEGIN
  -- Filtres
  v_body := '<form data-rpc="" method="get" action="' || pgv.call_ref('get_articles') || '">';
  v_body := v_body || '<div class="grid">';
  v_body := v_body || pgv.input('q', 'search', 'Recherche', v_q);

  -- Select catégorie
  v_cat_options := '<option value="">Toutes catégories</option>';
  FOR r IN SELECT c.id, c.nom FROM catalog.categorie c ORDER BY c.nom LOOP
    v_cat_options := v_cat_options || format('<option value="%s"%s>%s</option>',
      r.id, CASE WHEN r.id = v_categorie_id THEN ' selected' ELSE '' END, pgv.esc(r.nom));
  END LOOP;
  v_body := v_body || '<label>Catégorie<select name="categorie_id">' || v_cat_options || '</select></label>';

  -- Select actif
  v_body := v_body || '<label>Statut<select name="actif">'
    || format('<option value="tous"%s>Tous</option>', CASE WHEN v_actif = 'tous' THEN ' selected' ELSE '' END)
    || format('<option value="oui"%s>Actifs</option>', CASE WHEN v_actif = 'oui' THEN ' selected' ELSE '' END)
    || format('<option value="non"%s>Inactifs</option>', CASE WHEN v_actif = 'non' THEN ' selected' ELSE '' END)
    || '</select></label>';

  v_body := v_body || '</div><button type="submit" class="outline">Filtrer</button></form>';

  -- Liste articles
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.designation, c.nom AS categorie,
           a.prix_vente, a.prix_achat, u.label AS unite_label, a.tva, a.actif
    FROM catalog.article a
    LEFT JOIN catalog.categorie c ON c.id = a.categorie_id
    LEFT JOIN catalog.unite u ON u.code = a.unite
    WHERE (v_q IS NULL OR a.designation ILIKE '%' || v_q || '%' OR a.reference ILIKE '%' || v_q || '%')
      AND (v_categorie_id IS NULL OR a.categorie_id = v_categorie_id)
      AND (v_actif = 'tous' OR (v_actif = 'oui' AND a.actif) OR (v_actif = 'non' AND NOT a.actif))
    ORDER BY a.designation
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
      CASE WHEN r.prix_achat IS NOT NULL
        THEN to_char(r.prix_achat, 'FM999G990D00') || ' EUR'
        ELSE '—' END,
      coalesce(r.unite_label, r.unite_label),
      r.tva || '%',
      CASE WHEN r.actif THEN pgv.badge('Actif', 'success') ELSE pgv.badge('Inactif', 'warning') END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucun article trouvé', 'Modifiez vos filtres ou créez un article.');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Réf.', 'Désignation', 'Catégorie', 'PV HT', 'PA HT', 'Unité', 'TVA', 'Statut'],
      v_rows, 20
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">Nouvel article</a></p>',
    pgv.call_ref('get_article_form'));

  RETURN v_body;
END;
$function$;
