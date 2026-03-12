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
BEGIN
  v_body := '<form action="/notes" method="get">'
    || '<fieldset role="group">'
    || pgv.sel('statut', 'Statut', '[{"value":"","label":"Tous"},{"value":"brouillon","label":"Brouillon"},{"value":"soumise","label":"Soumise"},{"value":"validee","label":"Validée"},{"value":"remboursee","label":"Remboursée"},{"value":"rejetee","label":"Rejetée"}]'::jsonb, v_statut)
    || pgv.input('auteur', 'text', 'Auteur', v_auteur)
    || '</fieldset>'
    || '<button type="submit">Filtrer</button>'
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
      r.nb_lignes || ' ligne(s)',
      expense._statut_badge(r.statut),
      to_char(r.total_ttc, 'FM999 990.00') || ' EUR'
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucune note trouvée');
  ELSE
    v_body := v_body || pgv.md_table(ARRAY['Référence', 'Auteur', 'Période', 'Lignes', 'Statut', 'Total TTC'], v_rows, 15);
  END IF;

  v_body := v_body || '<p>'
    || format('<a href="%s" role="button">Nouvelle note</a>', pgv.call_ref('get_note_form'))
    || '</p>';

  RETURN v_body;
END;
$function$;
