CREATE OR REPLACE FUNCTION catalog.get_articles(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_q text := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_categorie_id text := NULLIF(trim(COALESCE(p_params->>'categorie_id', '')), '');
  v_actif text := NULLIF(trim(COALESCE(p_params->>'actif', '')), '');
  v_body text;
  v_rows text[];
  v_cat_opts jsonb;
  r record;
BEGIN
  -- Build category options
  SELECT COALESCE(jsonb_agg(jsonb_build_object('value', c.id::text, 'label', c.nom) ORDER BY c.nom), '[]'::jsonb)
  INTO v_cat_opts FROM catalog.categorie c;

  -- Filter form (GET)
  v_body := '<form>'
    || '<div class="grid">'
    || pgv.input('q', 'search', pgv.t('catalog.field_search'), v_q)
    || pgv.sel('categorie_id', pgv.t('catalog.field_categorie'), v_cat_opts, COALESCE(v_categorie_id, ''))
    || pgv.sel('actif', pgv.t('catalog.field_statut'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('catalog.filter_actifs'), 'value', 'oui'),
         jsonb_build_object('label', pgv.t('catalog.filter_inactifs'), 'value', 'non')
       ), COALESCE(v_actif, ''))
    || '</div>'
    || '<button type="submit" class="outline">' || pgv.t('catalog.btn_filter') || '</button>'
    || '</form>';

  -- Article list
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.designation, c.nom AS categorie,
           a.prix_vente, a.prix_achat, u.label AS unite_label, a.tva, a.actif
    FROM catalog.article a
    LEFT JOIN catalog.categorie c ON c.id = a.categorie_id
    LEFT JOIN catalog.unite u ON u.code = a.unite
    WHERE (v_q IS NULL OR a.designation ILIKE '%' || v_q || '%' OR a.reference ILIKE '%' || v_q || '%')
      AND (v_categorie_id IS NULL OR a.categorie_id = v_categorie_id::int)
      AND (v_actif IS NULL OR (v_actif = 'oui' AND a.actif) OR (v_actif = 'non' AND NOT a.actif))
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
      coalesce(r.unite_label, '—'),
      r.tva || '%',
      CASE WHEN r.actif THEN pgv.badge(pgv.t('catalog.badge_actif'), 'success') ELSE pgv.badge(pgv.t('catalog.badge_inactif'), 'warning') END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('catalog.empty_no_article_found'), pgv.t('catalog.empty_adjust_filters'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('catalog.col_ref'), pgv.t('catalog.col_designation'), pgv.t('catalog.col_categorie'), pgv.t('catalog.col_pv_ht'), pgv.t('catalog.col_pa_ht'), pgv.t('catalog.col_unite'), pgv.t('catalog.col_tva'), pgv.t('catalog.col_statut')],
      v_rows, 20
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">%s</a></p>',
    pgv.call_ref('get_article_form'), pgv.t('catalog.btn_new_article'));

  RETURN v_body;
END;
$function$;
