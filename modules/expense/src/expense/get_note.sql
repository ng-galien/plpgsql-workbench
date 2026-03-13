CREATE OR REPLACE FUNCTION expense.get_note(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_note record;
  v_body text;
  v_rows text[];
  v_total_ht numeric(12,2);
  v_total_tva numeric(12,2);
  v_total_ttc numeric(12,2);
  r record;
BEGIN
  IF p_id IS NULL THEN
    RETURN pgv.error('400', pgv.t('expense.err_id_requis'), pgv.t('expense.err_id_requis_detail'));
  END IF;

  SELECT * INTO v_note FROM expense.note WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.error('404', pgv.t('expense.err_not_found'), pgv.t('expense.err_not_found_detail'));
  END IF;

  v_body := pgv.dl(VARIADIC ARRAY[
    pgv.t('expense.dl_reference'), coalesce(v_note.reference, '#' || v_note.id),
    pgv.t('expense.dl_auteur'), pgv.esc(v_note.auteur),
    pgv.t('expense.dl_periode'), to_char(v_note.date_debut, 'DD/MM/YYYY') || ' - ' || to_char(v_note.date_fin, 'DD/MM/YYYY'),
    pgv.t('expense.dl_statut'), expense._statut_badge(v_note.statut),
    pgv.t('expense.dl_commentaire'), coalesce(pgv.esc(v_note.commentaire), '—')
  ]);

  v_rows := ARRAY[]::text[];
  v_total_ht := 0; v_total_tva := 0; v_total_ttc := 0;

  FOR r IN
    SELECT l.id, l.date_depense, c.nom AS categorie, l.description,
           l.montant_ht, l.tva, l.montant_ttc, l.km
      FROM expense.ligne l
      LEFT JOIN expense.categorie c ON c.id = l.categorie_id
     WHERE l.note_id = p_id
     ORDER BY l.date_depense, l.id
  LOOP
    v_total_ht := v_total_ht + r.montant_ht;
    v_total_tva := v_total_tva + r.tva;
    v_total_ttc := v_total_ttc + r.montant_ttc;

    v_rows := v_rows || ARRAY[
      to_char(r.date_depense, 'DD/MM/YYYY'),
      pgv.esc(coalesce(r.categorie, '—')),
      pgv.esc(r.description),
      CASE WHEN r.km IS NOT NULL THEN r.km || ' km' ELSE '—' END,
      to_char(r.montant_ht, 'FM999 990.00'),
      to_char(r.tva, 'FM999 990.00'),
      '<strong>' || to_char(r.montant_ttc, 'FM999 990.00') || '</strong>'
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('expense.empty_no_ligne'), pgv.t('expense.empty_add_ligne'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('expense.col_date'), pgv.t('expense.col_categorie'), pgv.t('expense.col_description'), pgv.t('expense.col_km'), pgv.t('expense.col_ht'), pgv.t('expense.col_tva'), pgv.t('expense.col_ttc')],
      v_rows
    );
    v_body := v_body || pgv.grid(VARIADIC ARRAY[
      pgv.stat(pgv.t('expense.stat_total_ht'), to_char(v_total_ht, 'FM999 990.00') || ' EUR'),
      pgv.stat(pgv.t('expense.stat_total_tva'), to_char(v_total_tva, 'FM999 990.00') || ' EUR'),
      pgv.stat(pgv.t('expense.stat_total_ttc'), to_char(v_total_ttc, 'FM999 990.00') || ' EUR')
    ]);
  END IF;

  v_body := v_body || '<p>';

  IF v_note.statut = 'brouillon' THEN
    v_body := v_body
      || pgv.action('post_ligne_ajouter', pgv.t('expense.btn_action_ajouter_ligne'),
           jsonb_build_object('note_id', p_id),
           NULL, 'primary')
      || ' '
      || pgv.action('post_note_soumettre', pgv.t('expense.btn_soumettre'),
           jsonb_build_object('id', p_id),
           pgv.t('expense.confirm_soumettre'), 'outline');
  ELSIF v_note.statut = 'soumise' THEN
    v_body := v_body
      || pgv.action('post_note_valider', pgv.t('expense.btn_valider'),
           jsonb_build_object('id', p_id),
           pgv.t('expense.confirm_valider'), 'primary')
      || ' '
      || pgv.action('post_note_rejeter', pgv.t('expense.btn_rejeter'),
           jsonb_build_object('id', p_id),
           pgv.t('expense.confirm_rejeter'), 'danger');
  ELSIF v_note.statut = 'validee' THEN
    v_body := v_body
      || pgv.action('post_note_rembourser', pgv.t('expense.btn_rembourser'),
           jsonb_build_object('id', p_id),
           pgv.t('expense.confirm_rembourser'), 'primary');
  END IF;

  v_body := v_body || '</p>';

  RETURN v_body;
END;
$function$;
