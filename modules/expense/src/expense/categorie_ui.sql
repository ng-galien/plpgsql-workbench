CREATE OR REPLACE FUNCTION expense.categorie_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_c expense.categorie;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('expense.nav_categories')),
        pgv.ui_table('categories', jsonb_build_array(
          pgv.ui_col('nom', pgv.t('expense.col_categorie'), pgv.ui_link('{nom}', '/expense/categories/{id}')),
          pgv.ui_col('code_comptable', pgv.t('expense.col_code_comptable'))
        ))
      ),
      'datasources', jsonb_build_object(
        'categories', pgv.ui_datasource('expense://categorie', 20, true, 'nom')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_c FROM expense.categorie WHERE id = p_slug::int;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link(E'\u2190 ' || pgv.t('expense.nav_categories'), '/expense/categories'),
        pgv.ui_heading(v_c.nom)
      ),
      pgv.ui_heading(pgv.t('expense.col_code_comptable'), 3),
      pgv.ui_text(COALESCE(v_c.code_comptable, '—'))
    )
  );
END;
$function$;
