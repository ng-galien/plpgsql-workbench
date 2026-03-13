CREATE OR REPLACE FUNCTION ledger.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_solde_banque numeric;
  v_ca_mois numeric;
  v_charges_mois numeric;
  v_resultat numeric;
  v_month_start date;
  v_month_end date;
  v_rows text[];
  r record;
BEGIN
  v_month_start := date_trunc('month', CURRENT_DATE)::date;
  v_month_end := (date_trunc('month', CURRENT_DATE) + interval '1 month' - interval '1 day')::date;

  -- KPIs
  SELECT ledger._account_balance(a.id) INTO v_solde_banque
    FROM ledger.account a WHERE a.code = '512';

  v_ca_mois := ledger._period_total('revenue', v_month_start, v_month_end);
  v_charges_mois := ledger._period_total('expense', v_month_start, v_month_end);
  v_resultat := coalesce(v_ca_mois, 0) - coalesce(v_charges_mois, 0);

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('ledger.stat_bank_balance'), to_char(coalesce(v_solde_banque, 0), 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_monthly_revenue'), to_char(coalesce(v_ca_mois, 0), 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_monthly_expenses'), to_char(coalesce(v_charges_mois, 0), 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_result'), to_char(v_resultat, 'FM999 990.00') || ' €')
  ]);

  -- Écritures récentes
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT je.id, je.entry_date, je.reference, je.description, je.posted,
           coalesce(sum(el.debit), 0) AS total_debit
      FROM ledger.journal_entry je
      LEFT JOIN ledger.entry_line el ON el.journal_entry_id = je.id
     GROUP BY je.id
     ORDER BY je.entry_date DESC, je.id DESC
     LIMIT 10
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.entry_date, 'DD/MM/YYYY'),
      format('<a href="%s">%s</a>', pgv.call_ref('get_entry', jsonb_build_object('p_id', r.id)), pgv.esc(r.reference)),
      pgv.esc(r.description),
      to_char(r.total_debit, 'FM999 990.00') || ' €',
      CASE WHEN r.posted THEN pgv.badge(pgv.t('ledger.badge_posted'), 'success') ELSE pgv.badge(pgv.t('ledger.badge_draft'), 'warning') END
    ];
  END LOOP;

  v_body := v_body || pgv.tabs(VARIADIC ARRAY[
    pgv.t('ledger.title_recent_entries'),
    CASE WHEN array_length(v_rows, 1) IS NULL
      THEN pgv.empty(pgv.t('ledger.empty_no_entry'), pgv.t('ledger.empty_first_entry'))
      ELSE pgv.md_table(ARRAY[pgv.t('ledger.col_date'), pgv.t('ledger.col_reference'), pgv.t('ledger.col_description'), pgv.t('ledger.col_amount'), pgv.t('ledger.col_status')], v_rows)
    END
  ]);

  v_body := v_body || '<p>' || pgv.form_dialog(
    'dlg-new-entry',
    pgv.t('ledger.title_new_entry'),
    pgv.input('entry_date', 'date', pgv.t('ledger.field_date'), to_char(CURRENT_DATE, 'YYYY-MM-DD'), true)
    || pgv.input('reference', 'text', pgv.t('ledger.field_reference'), '', true)
    || pgv.input('description', 'text', pgv.t('ledger.field_description'), '', true),
    'post_entry_save',
    pgv.t('ledger.btn_new_entry')
  ) || '</p>';

  RETURN v_body;
END;
$function$;
