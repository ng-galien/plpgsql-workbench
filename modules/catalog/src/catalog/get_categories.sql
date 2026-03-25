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
    SELECT c.id, c.name, p.name AS parent_name,
           (SELECT count(*)::int FROM catalog.article a WHERE a.category_id = c.id) AS article_count
    FROM catalog.category c
    LEFT JOIN catalog.category p ON p.id = c.parent_id
    ORDER BY coalesce(p.name, c.name), c.name
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.name),
      coalesce(pgv.esc(r.parent_name), '—'),
      r.article_count::text,
      format('<a href="%s">%s</a>',
        pgv.call_ref('get_articles', jsonb_build_object('category_id', r.id)),
        pgv.t('catalog.nav_articles'))
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty(pgv.t('catalog.empty_no_category'), pgv.t('catalog.empty_first_category'));
  ELSE
    v_body := pgv.md_table(
      ARRAY[pgv.t('catalog.col_name'), pgv.t('catalog.col_parent'), pgv.t('catalog.col_articles'), pgv.t('catalog.col_articles')],
      v_rows
    );
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('value', c.id::text, 'label', c.name) ORDER BY c.name), '[]'::jsonb)
  INTO v_parent_opts FROM catalog.category c WHERE c.parent_id IS NULL;

  v_body := v_body || '<h3>' || pgv.t('catalog.title_new_category') || '</h3>';
  v_form_body := '<div class="grid">'
    || pgv.input('name', 'text', pgv.t('catalog.col_name'), NULL, true)
    || pgv.sel('parent_id', pgv.t('catalog.field_parent_category'), v_parent_opts)
    || '</div>';

  v_body := v_body || pgv.form('post_category_create', v_form_body, pgv.t('catalog.btn_create'));

  RETURN v_body;
END;
$function$;
