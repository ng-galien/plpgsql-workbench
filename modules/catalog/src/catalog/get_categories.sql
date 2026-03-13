CREATE OR REPLACE FUNCTION catalog.get_categories()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  v_parent_opts jsonb;
  v_form_body text;
  r record;
BEGIN
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT c.id, c.nom, p.nom AS parent_nom,
           (SELECT count(*)::int FROM catalog.article a WHERE a.categorie_id = c.id) AS nb_articles
    FROM catalog.categorie c
    LEFT JOIN catalog.categorie p ON p.id = c.parent_id
    ORDER BY coalesce(p.nom, c.nom), c.nom
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.nom),
      coalesce(pgv.esc(r.parent_nom), '—'),
      r.nb_articles::text,
      format('<a href="%s">%s</a>',
        pgv.call_ref('get_articles', jsonb_build_object('categorie_id', r.id)),
        pgv.t('catalog.nav_articles'))
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty(pgv.t('catalog.empty_no_categorie'), pgv.t('catalog.empty_first_categorie'));
  ELSE
    v_body := pgv.md_table(
      ARRAY[pgv.t('catalog.col_nom'), pgv.t('catalog.col_parente'), pgv.t('catalog.col_articles'), pgv.t('catalog.col_voir')],
      v_rows
    );
  END IF;

  -- Parent category options
  SELECT COALESCE(jsonb_agg(jsonb_build_object('value', c.id::text, 'label', c.nom) ORDER BY c.nom), '[]'::jsonb)
  INTO v_parent_opts FROM catalog.categorie c WHERE c.parent_id IS NULL;

  -- Inline create form
  v_body := v_body || '<h3>' || pgv.t('catalog.title_new_categorie') || '</h3>';
  v_form_body := '<div class="grid">'
    || pgv.input('nom', 'text', pgv.t('catalog.col_nom'), NULL, true)
    || pgv.sel('parent_id', pgv.t('catalog.field_categorie_parente'), v_parent_opts)
    || '</div>';

  v_body := v_body || pgv.form('post_categorie_creer', v_form_body, pgv.t('catalog.btn_creer'));

  RETURN v_body;
END;
$function$;
