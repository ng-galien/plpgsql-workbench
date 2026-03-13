CREATE OR REPLACE FUNCTION ledger.get_balance(p_year integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_year integer;
  v_start date;
  v_end date;
  v_body text;
  v_rows text[];
  v_total_debit numeric := 0;
  v_total_credit numeric := 0;
  r record;
BEGIN
  v_year := coalesce(p_year, extract(year FROM CURRENT_DATE)::integer);
  v_start := make_date(v_year, 1, 1);
  v_end := make_date(v_year, 12, 31);

  v_body := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('ledger.btn_balance_check')]);

  -- Year selector
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.link_button(pgv.call_ref('get_balance', jsonb_build_object('p_year', v_year - 1)), (v_year - 1)::text, 'outline'),
    pgv.link_button(pgv.call_ref('get_balance', jsonb_build_object('p_year', v_year)), v_year::text),
    pgv.link_button(pgv.call_ref('get_balance', jsonb_build_object('p_year', v_year + 1)), (v_year + 1)::text, 'outline')
  ]);

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.code, a.label, a.type,
           coalesce(sum(el.debit), 0) AS total_debit,
           coalesce(sum(el.credit), 0) AS total_credit
      FROM ledger.account a
      LEFT JOIN ledger.entry_line el ON el.account_id = a.id
        AND EXISTS (SELECT 1 FROM ledger.journal_entry je
                     WHERE je.id = el.journal_entry_id AND je.posted = true
                       AND je.entry_date >= v_start AND je.entry_date <= v_end)
     WHERE a.active
     GROUP BY a.id, a.code, a.label, a.type
    HAVING coalesce(sum(el.debit), 0) <> 0 OR coalesce(sum(el.credit), 0) <> 0
     ORDER BY a.code
  LOOP
    v_total_debit := v_total_debit + r.total_debit;
    v_total_credit := v_total_credit + r.total_credit;
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_grand_livre', jsonb_build_object('p_account_id', (SELECT id FROM ledger.account WHERE code = r.code), 'p_year', v_year)), pgv.esc(r.code)),
      pgv.esc(r.label),
      to_char(r.total_debit, 'FM999 990.00') || ' €',
      to_char(r.total_credit, 'FM999 990.00') || ' €',
      to_char(r.total_debit - r.total_credit, 'FM999 990.00') || ' €'
    ];
  END LOOP;

  -- Stats
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('ledger.stat_total_debit'), to_char(v_total_debit, 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_total_credit'), to_char(v_total_credit, 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_gap'), to_char(v_total_debit - v_total_credit, 'FM999 990.00') || ' €',
      CASE WHEN v_total_debit = v_total_credit THEN pgv.t('ledger.stat_balance_ok') ELSE pgv.t('ledger.stat_imbalance') END)
  ]);

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('ledger.empty_no_movement_on') || ' ' || v_year);
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('ledger.col_code'), pgv.t('ledger.col_label'), pgv.t('ledger.col_debit'), pgv.t('ledger.col_credit'), pgv.t('ledger.col_balance')],
      v_rows, 20
    );
  END IF;

  RETURN v_body;
END;
$function$;
