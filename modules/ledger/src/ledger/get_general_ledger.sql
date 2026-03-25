CREATE OR REPLACE FUNCTION ledger.get_general_ledger(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_account_id integer;
  v_account record;
  v_year integer;
  v_start date;
  v_end date;
  v_body text;
  v_rows text[];
  v_cumul numeric := 0;
  v_total_debit numeric := 0;
  v_total_credit numeric := 0;
  r record;
BEGIN
  v_account_id := (p_params->>'p_account_id')::integer;
  IF v_account_id IS NULL THEN RAISE EXCEPTION 'p_account_id requis'; END IF;

  SELECT * INTO v_account FROM ledger.account WHERE id = v_account_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Compte % introuvable', v_account_id; END IF;

  v_year := coalesce((p_params->>'p_year')::integer, extract(year FROM CURRENT_DATE)::integer);
  v_start := make_date(v_year, 1, 1);
  v_end := make_date(v_year, 12, 31);

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    pgv.t('ledger.nav_balance'), pgv.call_ref('get_balance', jsonb_build_object('p_year', v_year)),
    v_account.code || ' — ' || v_account.label
  ]);

  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.link_button(pgv.call_ref('get_general_ledger', jsonb_build_object('p_account_id', v_account_id, 'p_year', v_year - 1)), (v_year - 1)::text, 'outline'),
    pgv.link_button(pgv.call_ref('get_general_ledger', jsonb_build_object('p_account_id', v_account_id, 'p_year', v_year)), v_year::text),
    pgv.link_button(pgv.call_ref('get_general_ledger', jsonb_build_object('p_account_id', v_account_id, 'p_year', v_year + 1)), (v_year + 1)::text, 'outline')
  ]);

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT je.id AS entry_id, je.entry_date, je.reference, el.label,
           el.debit, el.credit
      FROM ledger.entry_line el
      JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
     WHERE el.account_id = v_account_id
       AND je.posted = true
       AND je.entry_date >= v_start AND je.entry_date <= v_end
     ORDER BY je.entry_date, je.id
  LOOP
    v_cumul := v_cumul + r.debit - r.credit;
    v_total_debit := v_total_debit + r.debit;
    v_total_credit := v_total_credit + r.credit;
    v_rows := v_rows || ARRAY[
      to_char(r.entry_date, 'DD/MM/YYYY'),
      format('<a href="%s">%s</a>', pgv.call_ref('get_entry', jsonb_build_object('p_id', r.entry_id)), pgv.esc(r.reference)),
      pgv.esc(r.label),
      CASE WHEN r.debit > 0 THEN to_char(r.debit, 'FM999 990.00') ELSE '' END,
      CASE WHEN r.credit > 0 THEN to_char(r.credit, 'FM999 990.00') ELSE '' END,
      to_char(v_cumul, 'FM999 990.00')
    ];
  END LOOP;

  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('ledger.stat_total_debit'), to_char(v_total_debit, 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_total_credit'), to_char(v_total_credit, 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_balance'), to_char(v_cumul, 'FM999 990.00') || ' €')
  ]);

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('ledger.empty_no_movement_on') || ' ' || v_year, pgv.t('ledger.empty_no_posted_period'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('ledger.col_date'), pgv.t('ledger.col_reference'), pgv.t('ledger.col_label'), pgv.t('ledger.col_debit'), pgv.t('ledger.col_credit'), pgv.t('ledger.col_cumulative')],
      v_rows, 20
    );
  END IF;

  RETURN v_body;
END;
$function$;
