CREATE OR REPLACE FUNCTION ledger.get_balance_sheet(p_year integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_year integer;
  v_start date;
  v_end date;
  v_body text;
  v_rows_r text[];
  v_rows_e text[];
  v_total_revenue numeric := 0;
  v_total_expense numeric := 0;
  v_resultat numeric;
  r record;
BEGIN
  v_year := coalesce(p_year, extract(year FROM CURRENT_DATE)::integer);
  v_start := make_date(v_year, 1, 1);
  v_end := make_date(v_year, 12, 31);

  v_body := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('ledger.nav_balance_sheet')]);

  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.link_button(pgv.call_ref('get_balance_sheet', jsonb_build_object('p_year', v_year - 1)), (v_year - 1)::text, 'outline'),
    pgv.link_button(pgv.call_ref('get_balance_sheet', jsonb_build_object('p_year', v_year)), v_year::text),
    pgv.link_button(pgv.call_ref('get_balance_sheet', jsonb_build_object('p_year', v_year + 1)), (v_year + 1)::text, 'outline')
  ]);

  v_rows_r := ARRAY[]::text[];
  FOR r IN
    SELECT a.code, a.label,
           coalesce(sum(el.credit) - sum(el.debit), 0) AS balance
      FROM ledger.account a
      LEFT JOIN ledger.entry_line el ON el.account_id = a.id
        AND EXISTS (SELECT 1 FROM ledger.journal_entry je
                     WHERE je.id = el.journal_entry_id AND je.posted = true
                       AND je.entry_date >= v_start AND je.entry_date <= v_end)
     WHERE a.type = 'revenue' AND a.active
     GROUP BY a.id, a.code, a.label
     ORDER BY a.code
  LOOP
    v_total_revenue := v_total_revenue + r.balance;
    IF r.balance <> 0 THEN
      v_rows_r := v_rows_r || ARRAY[
        pgv.esc(r.code), pgv.esc(r.label),
        to_char(r.balance, 'FM999 990.00') || ' €'
      ];
    END IF;
  END LOOP;

  v_rows_e := ARRAY[]::text[];
  FOR r IN
    SELECT a.code, a.label,
           coalesce(sum(el.debit) - sum(el.credit), 0) AS balance
      FROM ledger.account a
      LEFT JOIN ledger.entry_line el ON el.account_id = a.id
        AND EXISTS (SELECT 1 FROM ledger.journal_entry je
                     WHERE je.id = el.journal_entry_id AND je.posted = true
                       AND je.entry_date >= v_start AND je.entry_date <= v_end)
     WHERE a.type = 'expense' AND a.active
     GROUP BY a.id, a.code, a.label
     ORDER BY a.code
  LOOP
    v_total_expense := v_total_expense + r.balance;
    IF r.balance <> 0 THEN
      v_rows_e := v_rows_e || ARRAY[
        pgv.esc(r.code), pgv.esc(r.label),
        to_char(r.balance, 'FM999 990.00') || ' €'
      ];
    END IF;
  END LOOP;

  v_resultat := v_total_revenue - v_total_expense;

  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('ledger.stat_revenue'), to_char(v_total_revenue, 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_expenses'), to_char(v_total_expense, 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_result_net'), to_char(v_resultat, 'FM999 990.00') || ' €',
      CASE WHEN v_resultat >= 0 THEN pgv.t('ledger.stat_benefit') ELSE pgv.t('ledger.stat_deficit') END)
  ]);

  v_body := v_body || pgv.tabs(VARIADIC ARRAY[
    pgv.t('ledger.title_revenue'),
    CASE WHEN array_length(v_rows_r, 1) IS NULL
      THEN pgv.empty(pgv.t('ledger.empty_no_revenue_on') || ' ' || v_year)
      ELSE pgv.md_table(ARRAY[pgv.t('ledger.col_code'), pgv.t('ledger.col_label'), pgv.t('ledger.col_amount')], v_rows_r)
        || '<p><strong>' || pgv.t('ledger.total_revenue') || ' : ' || to_char(v_total_revenue, 'FM999 990.00') || ' €</strong></p>'
    END,
    pgv.t('ledger.title_expenses'),
    CASE WHEN array_length(v_rows_e, 1) IS NULL
      THEN pgv.empty(pgv.t('ledger.empty_no_expense_on') || ' ' || v_year)
      ELSE pgv.md_table(ARRAY[pgv.t('ledger.col_code'), pgv.t('ledger.col_label'), pgv.t('ledger.col_amount')], v_rows_e)
        || '<p><strong>' || pgv.t('ledger.total_expenses') || ' : ' || to_char(v_total_expense, 'FM999 990.00') || ' €</strong></p>'
    END
  ]);

  RETURN v_body;
END;
$function$;
