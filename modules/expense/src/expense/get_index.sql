CREATE OR REPLACE FUNCTION expense.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_nb_notes int;
  v_total_en_cours numeric(12,2);
  v_montant_moyen numeric(12,2);
  v_nb_a_valider int;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  SELECT count(*)::int INTO v_nb_notes FROM expense.note;

  SELECT coalesce(sum(l.montant_ttc), 0)
    INTO v_total_en_cours
    FROM expense.note n
    JOIN expense.ligne l ON l.note_id = n.id
   WHERE n.statut IN ('brouillon', 'soumise', 'validee');

  SELECT coalesce(avg(sub.total), 0)
    INTO v_montant_moyen
    FROM (
      SELECT sum(l.montant_ttc) AS total
        FROM expense.ligne l
       GROUP BY l.note_id
    ) sub;

  SELECT count(*)::int INTO v_nb_a_valider
    FROM expense.note WHERE statut = 'soumise';

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Notes de frais', v_nb_notes::text),
    pgv.stat('Total en cours', to_char(v_total_en_cours, 'FM999 990.00') || ' EUR'),
    pgv.stat('Montant moyen', to_char(v_montant_moyen, 'FM999 990.00') || ' EUR'),
    pgv.stat('A valider', v_nb_a_valider::text)
  ]);

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT n.id, n.reference, n.auteur, n.statut, n.date_debut, n.date_fin,
           coalesce(sum(l.montant_ttc), 0) AS total_ttc,
           count(l.id)::int AS nb_lignes
      FROM expense.note n
      LEFT JOIN expense.ligne l ON l.note_id = n.id
     GROUP BY n.id
     ORDER BY n.created_at DESC LIMIT 10
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_note', jsonb_build_object('p_id', r.id)), pgv.esc(coalesce(r.reference, '#' || r.id))),
      pgv.esc(r.auteur),
      to_char(r.date_debut, 'DD/MM') || ' - ' || to_char(r.date_fin, 'DD/MM/YYYY'),
      r.nb_lignes || ' ligne(s)',
      expense._statut_badge(r.statut),
      to_char(r.total_ttc, 'FM999 990.00') || ' EUR'
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucune note de frais', 'Créez votre première note pour commencer.');
  ELSE
    v_body := v_body || pgv.md_table(ARRAY['Référence', 'Auteur', 'Période', 'Lignes', 'Statut', 'Total TTC'], v_rows);
  END IF;

  v_body := v_body || '<p>'
    || format('<a href="%s" role="button">Nouvelle note</a>', pgv.call_ref('get_note_form'))
    || '</p>';

  RETURN v_body;
END;
$function$;
