CREATE OR REPLACE FUNCTION expense.note_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_n expense.note;
  v_total_ht numeric;
  v_total_ttc numeric;
  v_nb_lignes int;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('expense.nav_notes')),
        pgv.ui_table('notes', jsonb_build_array(
          pgv.ui_col('reference', pgv.t('expense.col_reference'), pgv.ui_link('{reference}', '/expense/notes/{id}')),
          pgv.ui_col('auteur', pgv.t('expense.col_auteur')),
          pgv.ui_col('date_debut', pgv.t('expense.col_date_debut')),
          pgv.ui_col('date_fin', pgv.t('expense.col_date_fin')),
          pgv.ui_col('statut', pgv.t('expense.col_statut'), pgv.ui_badge('{statut}')),
          pgv.ui_col('nb_lignes', pgv.t('expense.col_nb_lignes')),
          pgv.ui_col('total_ttc', pgv.t('expense.col_total_ttc'))
        ))
      ),
      'datasources', jsonb_build_object(
        'notes', pgv.ui_datasource('expense://note', 20, true, 'updated_at:desc')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_n FROM expense.note WHERE id = p_slug::int OR reference = p_slug;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT count(*), COALESCE(sum(montant_ht), 0), COALESCE(sum(montant_ttc), 0)
  INTO v_nb_lignes, v_total_ht, v_total_ttc
  FROM expense.ligne WHERE note_id = v_n.id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      -- Header
      pgv.ui_row(
        pgv.ui_link(E'\u2190 ' || pgv.t('expense.nav_notes'), '/expense/notes'),
        pgv.ui_heading(v_n.reference)
      ),
      pgv.ui_badge(v_n.statut),

      -- Info
      pgv.ui_heading(pgv.t('expense.dl_auteur'), 3),
      pgv.ui_text(v_n.auteur),
      pgv.ui_heading(pgv.t('expense.dl_periode'), 3),
      pgv.ui_text(v_n.date_debut::text || ' → ' || v_n.date_fin::text),
      pgv.ui_text(COALESCE(v_n.commentaire, '')),

      -- Totaux
      pgv.ui_heading(pgv.t('expense.stat_total'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('expense.col_nb_lignes') || ': ' || v_nb_lignes),
        pgv.ui_text('HT: ' || v_total_ht::text || ' €'),
        pgv.ui_text('TTC: ' || v_total_ttc::text || ' €')
      )
    )
  );
END;
$function$;
