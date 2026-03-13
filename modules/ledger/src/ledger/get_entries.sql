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
      to_char(r.total_debit, 'FM999 990.00') || ' €',
      CASE WHEN r.posted THEN pgv.badge(pgv.t('ledger.badge_posted'), 'success') ELSE pgv.badge(pgv.t('ledger.badge_draft'), 'warning') END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty(pgv.t('ledger.empty_no_entry'), pgv.t('ledger.empty_first_entry_accounting'));
  ELSE
    v_body := pgv.md_table(
      ARRAY[pgv.t('ledger.col_date'), pgv.t('ledger.col_reference'), pgv.t('ledger.col_description'), pgv.t('ledger.col_amount'), pgv.t('ledger.col_status')],
      v_rows, 15
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">%s</a></p>', pgv.call_ref('get_entry_form'), pgv.t('ledger.btn_new_entry'));

  RETURN pgv.breadcrumb(VARIADIC ARRAY[pgv.t('ledger.nav_entries')]) || v_body;
END;
$function$;
