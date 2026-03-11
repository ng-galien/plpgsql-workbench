CREATE OR REPLACE FUNCTION ledger.get_entries()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rows text[];
  v_body text;
  r record;
BEGIN
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT je.id, je.entry_date, je.reference, je.description, je.posted,
           coalesce(sum(el.debit), 0) AS total_debit
      FROM ledger.journal_entry je
      LEFT JOIN ledger.entry_line el ON el.journal_entry_id = je.id
     GROUP BY je.id
     ORDER BY je.entry_date DESC, je.id DESC
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.entry_date, 'DD/MM/YYYY'),
      format('<a href="%s">%s</a>', pgv.call_ref('get_entry', jsonb_build_object('p_id', r.id)), pgv.esc(r.reference)),
      pgv.esc(r.description),
      to_char(r.total_debit, 'FM999 999.00') || ' €',
      CASE WHEN r.posted THEN pgv.badge('Validée', 'success') ELSE pgv.badge('Brouillon', 'warning') END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty('Aucune écriture', 'Créez votre première écriture comptable.');
  ELSE
    v_body := pgv.md_table(
      ARRAY['Date', 'Référence', 'Description', 'Montant', 'Statut'],
      v_rows, 15
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">Nouvelle écriture</a></p>', pgv.call_ref('get_entry_form'));

  RETURN pgv.breadcrumb(VARIADIC ARRAY['Écritures']) || v_body;
END;
$function$;
