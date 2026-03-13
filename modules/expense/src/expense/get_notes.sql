CREATE OR REPLACE FUNCTION expense.get_notes(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_statut text := p_params->>'statut';
  v_auteur text := p_params->>'auteur';
  v_body text;
  v_rows text[];
  r record;
  v_options jsonb;
BEGIN
  v_options := jsonb_build_array(
    jsonb_build_object('value', '', 'label', pgv.t('expense.filter_tous')),
    jsonb_build_object('value', 'brouillon', 'label', pgv.t('expense.filter_brouillon')),
    jsonb_build_object('value', 'soumise', 'label', pgv.t('expense.filter_soumise')),
    jsonb_build_object('value', 'validee', 'label', pgv.t('expense.filter_validee')),
    jsonb_build_object('value', 'remboursee', 'label', pgv.t('expense.filter_remboursee')),
    jsonb_build_object('value', 'rejetee', 'label', pgv.t('expense.filter_rejetee'))
  );

  v_body := '<form action="/notes" method="get">'
    || '<fieldset role="group">'
    || pgv.sel('statut', pgv.t('expense.field_statut'), v_options, v_statut)
    || pgv.input('auteur', 'text', pgv.t('expense.field_auteur'), v_auteur)
    || '</fieldset>'
    || '<button type="submit">' || pgv.t('expense.btn_filtrer') || '</button>'
    || '</form>';

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT n.id, n.reference, n.auteur, n.statut, n.date_debut, n.date_fin,
           coalesce(sum(l.montant_ttc), 0) AS total_ttc,
           count(l.id)::int AS nb_lignes
      FROM expense.note n
      LEFT JOIN expense.ligne l ON l.note_id = n.id
     WHERE (v_statut IS NULL OR n.statut = v_statut)
       AND (v_auteur IS NULL OR n.auteur ILIKE '%' || v_auteur || '%')
     GROUP BY n.id
     ORDER BY n.created_at DESC
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_note', jsonb_build_object('p_id', r.id)), pgv.esc(coalesce(r.reference, '#' || r.id))),
      pgv.esc(r.auteur),
      to_char(r.date_debut, 'DD/MM') || ' - ' || to_char(r.date_fin, 'DD/MM/YYYY'),
      r.nb_lignes || ' ' || pgv.t('expense.count_lignes'),
      expense._statut_badge(r.statut),
      to_char(r.total_ttc, 'FM999 990.00') || ' EUR'
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('expense.empty_no_results'));
  ELSE
    v_body := v_body || pgv.md_table(ARRAY[pgv.t('expense.col_reference'), pgv.t('expense.col_auteur'), pgv.t('expense.col_periode'), pgv.t('expense.col_lignes'), pgv.t('expense.col_statut'), pgv.t('expense.col_total_ttc')], v_rows, 15);
  END IF;

  v_body := v_body || '<p>'
    || pgv.form_dialog('dlg-new-note', pgv.t('expense.btn_nouvelle_note'), expense._note_form_body(), 'post_note_creer')
    || '</p>';

  RETURN v_body;
END;
$function$;
