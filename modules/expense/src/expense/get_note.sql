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
    RETURN pgv.error('400', 'ID requis', 'Spécifiez un identifiant de note.');
  END IF;

  SELECT * INTO v_note FROM expense.note WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.error('404', 'Note introuvable', 'La note #' || p_id || ' n''existe pas.');
  END IF;

  -- En-tête
  v_body := pgv.dl(VARIADIC ARRAY[
    'Référence', coalesce(v_note.reference, '#' || v_note.id),
    'Auteur', pgv.esc(v_note.auteur),
    'Période', to_char(v_note.date_debut, 'DD/MM/YYYY') || ' - ' || to_char(v_note.date_fin, 'DD/MM/YYYY'),
    'Statut', expense._statut_badge(v_note.statut),
    'Commentaire', coalesce(pgv.esc(v_note.commentaire), '—')
  ]);

  -- Lignes
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
    v_body := v_body || pgv.empty('Aucune ligne', 'Ajoutez des dépenses à cette note.');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Date', 'Catégorie', 'Description', 'Km', 'HT', 'TVA', 'TTC'],
      v_rows
    );
    -- Totaux
    v_body := v_body || pgv.grid(VARIADIC ARRAY[
      pgv.stat('Total HT', to_char(v_total_ht, 'FM999 990.00') || ' EUR'),
      pgv.stat('Total TVA', to_char(v_total_tva, 'FM999 990.00') || ' EUR'),
      pgv.stat('Total TTC', to_char(v_total_ttc, 'FM999 990.00') || ' EUR')
    ]);
  END IF;

  -- Actions selon statut
  v_body := v_body || '<p>';

  IF v_note.statut = 'brouillon' THEN
    v_body := v_body
      || pgv.action('post_ligne_ajouter', 'Ajouter une ligne',
           jsonb_build_object('note_id', p_id),
           NULL, 'primary')
      || ' '
      || pgv.action('post_note_soumettre', 'Soumettre',
           jsonb_build_object('id', p_id),
           'Soumettre cette note pour validation ?', 'outline');
  ELSIF v_note.statut = 'soumise' THEN
    v_body := v_body
      || pgv.action('post_note_valider', 'Valider',
           jsonb_build_object('id', p_id),
           'Valider cette note de frais ?', 'primary')
      || ' '
      || pgv.action('post_note_rejeter', 'Rejeter',
           jsonb_build_object('id', p_id),
           'Rejeter cette note de frais ?', 'danger');
  ELSIF v_note.statut = 'validee' THEN
    v_body := v_body
      || pgv.action('post_note_rembourser', 'Rembourser',
           jsonb_build_object('id', p_id),
           'Marquer cette note comme remboursée ?', 'primary');
  END IF;

  v_body := v_body || '</p>';

  RETURN v_body;
END;
$function$;
