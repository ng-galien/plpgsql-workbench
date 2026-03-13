CREATE OR REPLACE FUNCTION ledger.get_exercice(p_year integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_year integer;
  v_start date;
  v_end date;
  v_body text;
  v_exercice record;
  v_total_revenue numeric;
  v_total_expense numeric;
  v_resultat numeric;
  v_entry_count integer;
  v_draft_count integer;
BEGIN
  v_year := coalesce(p_year, extract(year FROM CURRENT_DATE)::integer);
  v_start := make_date(v_year, 1, 1);
  v_end := make_date(v_year, 12, 31);

  v_body := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('ledger.nav_exercice') || ' ' || v_year]);

  -- Year selector
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    format('<a href="%s" role="button" class="outline">%s</a>', pgv.call_ref('get_exercice', jsonb_build_object('p_year', v_year - 1)), (v_year - 1)::text),
    format('<a href="%s" role="button">%s</a>', pgv.call_ref('get_exercice', jsonb_build_object('p_year', v_year)), v_year::text),
    format('<a href="%s" role="button" class="outline">%s</a>', pgv.call_ref('get_exercice', jsonb_build_object('p_year', v_year + 1)), (v_year + 1)::text)
  ]);

  -- Exercice status
  SELECT * INTO v_exercice FROM ledger.exercice WHERE year = v_year;

  -- Compute totals from posted entries
  SELECT coalesce(sum(CASE WHEN a.type = 'revenue' THEN el.credit - el.debit ELSE 0 END), 0),
         coalesce(sum(CASE WHEN a.type = 'expense' THEN el.debit - el.credit ELSE 0 END), 0)
    INTO v_total_revenue, v_total_expense
    FROM ledger.entry_line el
    JOIN ledger.account a ON a.id = el.account_id
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
   WHERE je.posted = true
     AND je.entry_date >= v_start AND je.entry_date <= v_end;

  v_resultat := v_total_revenue - v_total_expense;

  SELECT count(*), count(*) FILTER (WHERE NOT posted)
    INTO v_entry_count, v_draft_count
    FROM ledger.journal_entry
   WHERE entry_date >= v_start AND entry_date <= v_end;

  -- Stats
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('ledger.stat_status'),
      CASE WHEN v_exercice.closed THEN pgv.badge(pgv.t('ledger.badge_closed'), 'success')
           ELSE pgv.badge(pgv.t('ledger.badge_open'), 'warning') END),
    pgv.stat(pgv.t('ledger.stat_revenue'), to_char(v_total_revenue, 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_expenses'), to_char(v_total_expense, 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_result'), to_char(v_resultat, 'FM999 990.00') || ' €',
      CASE WHEN v_resultat >= 0 THEN pgv.t('ledger.stat_benefit') ELSE pgv.t('ledger.stat_deficit') END)
  ]);

  -- Entries summary
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('ledger.stat_entries'), v_entry_count::text),
    pgv.stat(pgv.t('ledger.stat_drafts'), v_draft_count::text,
      CASE WHEN v_draft_count > 0 THEN pgv.t('ledger.stat_drafts_hint') ELSE NULL END)
  ]);

  -- Links
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    format('<a href="%s" role="button" class="outline">%s</a>', pgv.call_ref('get_balance', jsonb_build_object('p_year', v_year)), pgv.t('ledger.btn_balance_check')),
    format('<a href="%s" role="button" class="outline">%s</a>', pgv.call_ref('get_bilan', jsonb_build_object('p_year', v_year)), pgv.t('ledger.btn_bilan_pl'))
  ]);

  -- Clôture action
  IF NOT coalesce(v_exercice.closed, false) THEN
    v_body := v_body || pgv.action(
      'post_cloture',
      pgv.t('ledger.btn_close_exercice') || ' ' || v_year,
      jsonb_build_object('year', v_year),
      pgv.t('ledger.confirm_close_exercice') || ' ' || v_year || ' ' || pgv.t('ledger.confirm_close_suffix')
    );
  ELSE
    v_body := v_body || '<p>' || pgv.t('ledger.closed_on') || ' '
      || to_char(v_exercice.closed_at, 'DD/MM/YYYY à HH24:MI')
      || ' — ' || pgv.t('ledger.result_recorded') || ' : ' || to_char(v_exercice.result, 'FM999 990.00') || ' €</p>';
  END IF;

  RETURN v_body;
END;
$function$;
